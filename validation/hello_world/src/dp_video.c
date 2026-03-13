/*
 * dp_video.c
 * PS DisplayPort TX + DPDMA output driver for ZynqMP.
 *
 * Configures the PS-side DisplayPort transmitter to output 1280x720@60Hz
 * from an ARGB8888 pixel buffer in DDR via DPDMA.  No PL fabric required.
 *
 * Initialization sequence follows the Xilinx reference example
 * (xdpdma_video_example.c / xdppsu_interrupt.c).
 *
 * Uses Xilinx BSP drivers: XDpPsu, XAVBuf, XDpDma.
 */

#include "dp_video.h"
#include "text_fb.h"
#include "xil_printf.h"
#include "sleep.h"

#include "xdpdma.h"
#include "xdppsu.h"
#include "xdppsu_hw.h"
#include "xavbuf.h"
#include "xavbuf_clk.h"
#include "xil_cache.h"
#include "xparameters.h"

/* Driver instances */
static XDpPsu       dp_inst;
static XDpDma       dma_inst;
static XAVBuf       avbuf_inst;

/* DPDMA frame buffer descriptor — must be 256-byte aligned */
static XDpDma_FrameBuffer dma_fb __attribute__((aligned(256)));

/*
 * Callback stubs for the DP driver (HPD events).
 * Required by XDpPsu but we just handle them minimally.
 */
static void dp_hpd_event(void *ref)
{
    (void)ref;
    xil_printf("[DP] HPD event\r\n");
}

static void dp_hpd_pulse(void *ref)
{
    (void)ref;
    xil_printf("[DP] HPD pulse\r\n");
}

int dp_video_init(uint32_t *pixel_buf)
{
    XDpPsu_Config *dp_cfg;
    XDpDma_Config *dma_cfg;
    u32 status;

    xil_printf("[DP] Initializing DisplayPort TX...\r\n");

    /* =================================================================
     * Phase 1: Subsystem init (DP controller, AVBuf, DPDMA)
     * ================================================================= */

    /* --- DP controller --- */
    dp_cfg = XDpPsu_LookupConfig(XPAR_XDPPSU_0_BASEADDR);
    if (!dp_cfg) {
        xil_printf("[DP] ERROR: DP config not found\r\n");
        return -1;
    }

    XDpPsu_CfgInitialize(&dp_inst, dp_cfg, dp_cfg->BaseAddr);

    /* --- AVBuf --- */
    XAVBuf_CfgInitialize(&avbuf_inst, dp_inst.Config.BaseAddr);

    /* --- DPDMA --- */
    dma_cfg = XDpDma_LookupConfig(XPAR_XDPDMA_0_BASEADDR);
    if (!dma_cfg) {
        xil_printf("[DP] ERROR: DPDMA config not found\r\n");
        return -1;
    }
    XDpDma_CfgInitialize(&dma_inst, dma_cfg);

    /* --- DP TX core init (PHY, clocks) --- */
    status = XDpPsu_InitializeTx(&dp_inst);
    if (status != XST_SUCCESS) {
        xil_printf("[DP] ERROR: TX init failed (%lu)\r\n", (unsigned long)status);
        return -2;
    }

    /* Set HPD callbacks */
    XDpPsu_SetHpdEventHandler(&dp_inst, dp_hpd_event, &dp_inst);
    XDpPsu_SetHpdPulseHandler(&dp_inst, dp_hpd_pulse, &dp_inst);

    /* --- Configure DPDMA graphics format and QoS --- */
    /* Framebuffer stores 0xAARRGGBB in each u32.  Xilinx ABGR8888 maps
     * bits [31:24]=A [23:16]=B [15:8]=G [7:0]=R — which on little-endian
     * AArch64 reads our A byte from the MSB position correctly.  Using
     * RGBA8888 would put R in bits [31:24], making alpha=0 on every pixel
     * and the blender would render everything as transparent black. */
    XDpDma_SetGraphicsFormat(&dma_inst, RGBA8888);
    XAVBuf_SetInputNonLiveGraphicsFormat(&avbuf_inst, RGBA8888);
    XDpDma_SetQOS(&dma_inst, 11);

    /* Enable graphics buffers early (before link training) */
    XAVBuf_EnableGraphicsBuffers(&avbuf_inst, 1);

    /* Configure blender output format */
    XAVBuf_SetOutputVideoFormat(&avbuf_inst, RGB_8BPC);

    /* Select graphics-only input: no video stream 1, non-live graphics */
    XAVBuf_InputVideoSelect(&avbuf_inst, XAVBUF_VIDSTREAM1_NONE,
                            XAVBUF_VIDSTREAM2_NONLIVE_GFX);

    /* Configure graphics pipeline scaling factors */
    XAVBuf_ConfigureGraphicsPipeline(&avbuf_inst);

    /* Configure blender output pipeline */
    XAVBuf_ConfigureOutputVideo(&avbuf_inst);

    /* Blender alpha: disabled (graphics-only, no blending) */
    XAVBuf_SetBlenderAlpha(&avbuf_inst, 0, 0);

    /* Disable synchronous clock mode */
    XDpPsu_CfgMsaEnSynchClkMode(&dp_inst, 0);

    /* Select PS PLL as video and audio clock source */
    XAVBuf_SetAudioVideoClkSrc(&avbuf_inst, XAVBUF_PS_CLK, XAVBUF_PS_CLK);

    /* Soft-reset AVBuf to latch clock source changes */
    XAVBuf_SoftReset(&avbuf_inst);

    /* =================================================================
     * Phase 2: Link training
     * ================================================================= */

    xil_printf("[DP] Checking for monitor (HPD)...\r\n");

    if (!XDpPsu_IsConnected(&dp_inst)) {
        xil_printf("[DP] No monitor detected — skipping link training\r\n");
        xil_printf("[DP] DPDMA configured but no video output\r\n");
        return 0;
    }

    /* Disable main link before training */
    XDpPsu_EnableMainLink(&dp_inst, 0);

    /* Read sink (monitor) capabilities via AUX/DPCD */
    status = XDpPsu_GetRxCapabilities(&dp_inst);
    if (status != XST_SUCCESS) {
        xil_printf("[DP] WARNING: Could not read sink caps (%lu)\r\n",
                   (unsigned long)status);
    }

    /* Link parameters */
    XDpPsu_SetLinkRate(&dp_inst, XDPPSU_LINK_BW_SET_270GBPS);
    XDpPsu_SetLaneCount(&dp_inst, 2);
    XDpPsu_SetEnhancedFrameMode(&dp_inst, 1);
    XDpPsu_SetDownspread(&dp_inst, 0);

    status = XDpPsu_EstablishLink(&dp_inst);
    if (status != XST_SUCCESS) {
        xil_printf("[DP] WARNING: Link training failed (%lu), "
                   "trying 1 lane...\r\n", (unsigned long)status);
        XDpPsu_SetLaneCount(&dp_inst, 1);
        status = XDpPsu_EstablishLink(&dp_inst);
        if (status != XST_SUCCESS) {
            xil_printf("[DP] ERROR: Link training failed (%lu)\r\n",
                       (unsigned long)status);
            return -3;
        }
    }

    xil_printf("[DP] Link established: %d lane(s)\r\n",
               dp_inst.LinkConfig.LaneCount);

    /* =================================================================
     * Phase 3: Video stream setup + DPDMA trigger
     * ================================================================= */

    /* Configure the graphics channel framebuffer */
    dma_fb.Address = (UINTPTR)pixel_buf;
    dma_fb.Stride  = SCREEN_W * 4;  /* bytes per scanline */
    dma_fb.LineSize = SCREEN_W * 4;
    dma_fb.Size    = SCREEN_W * SCREEN_H * 4;

    /* Register framebuffer with DPDMA before MSA setup */
    XDpDma_DisplayGfxFrameBuffer(&dma_inst, &dma_fb);

    /* MSA configuration — BitsPerColor must be set first */
    XDpPsu_SetColorEncode(&dp_inst, XDPPSU_CENC_RGB);
    XDpPsu_CfgMsaSetBpc(&dp_inst, 8);
    XDpPsu_CfgMsaUseStandardVideoMode(&dp_inst, XVIDC_VM_1280x720_60_P);

    /* Set pixel clock from the MSA-derived value */
    XAVBuf_SetPixelClock(dp_inst.MsaConfig.PixelClockHz);

    /* DP soft reset */
    XDpPsu_WriteReg(dp_inst.Config.BaseAddr, XDPPSU_SOFT_RESET, 0x1);
    usleep(10);
    XDpPsu_WriteReg(dp_inst.Config.BaseAddr, XDPPSU_SOFT_RESET, 0x0);

    /* Write MSA values to hardware */
    XDpPsu_SetMsaValues(&dp_inst);

    /* AVBuf soft reset (register 0xB124 relative to DP base) */
    XDpPsu_WriteReg(dp_inst.Config.BaseAddr, 0xB124, 0x3);
    usleep(10);
    XDpPsu_WriteReg(dp_inst.Config.BaseAddr, 0xB124, 0x0);

    /* Flush cache so DPDMA sees the pixel data */
    Xil_DCacheFlushRange((UINTPTR)pixel_buf, PIXEL_BUF_SIZE);

    /* Build DMA descriptors, enable channel, and trigger.
     * The descriptors live inside dma_inst (cached BSS).  The DPDMA
     * hardware reads them via DMA, so we must flush the descriptor
     * memory after SetupChannel writes them. */
    XDpDma_SetupChannel(&dma_inst, GraphicsChan);
    Xil_DCacheFlushRange((UINTPTR)&dma_inst, sizeof(dma_inst));
    XDpDma_SetChannelState(&dma_inst, GraphicsChan, XDPDMA_ENABLE);
    XDpDma_Trigger(&dma_inst, GraphicsChan);

    /* Enable main link */
    XDpPsu_EnableMainLink(&dp_inst, 1);

    xil_printf("[DP] Video output active (1280x720@60 RGBA8888)\r\n");
    return 0;
}

void dp_video_set_buffer(uint32_t *pixel_buf)
{
    dma_fb.Address = (UINTPTR)pixel_buf;
    XDpDma_DisplayGfxFrameBuffer(&dma_inst, &dma_fb);
}

void dp_video_refresh(void)
{
    /* Update descriptors and retrigger for the current framebuffer.
     * Without VSync interrupts we must do this manually. */
    XDpDma_DisplayGfxFrameBuffer(&dma_inst, &dma_fb);
    XDpDma_SetupChannel(&dma_inst, GraphicsChan);
    Xil_DCacheFlushRange((UINTPTR)&dma_inst, sizeof(dma_inst));
    XDpDma_ReTrigger(&dma_inst, GraphicsChan);
}
