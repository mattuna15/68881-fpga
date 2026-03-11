/*
 * dp_video.c
 * PS DisplayPort TX + DPDMA output driver for ZynqMP.
 *
 * Configures the PS-side DisplayPort transmitter to output 1280x720@60Hz
 * from an ARGB8888 pixel buffer in DDR via DPDMA.  No PL fabric required.
 *
 * Uses Xilinx BSP drivers: XDpPsu, XAVBuf, XDpDma.
 */

#include "dp_video.h"
#include "text_fb.h"
#include "xil_printf.h"

#include "xdpdma.h"
#include "xdppsu.h"
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

    /* --- DP controller --- */
    dp_cfg = XDpPsu_LookupConfig(XPAR_XDPPSU_0_BASEADDR);
    if (!dp_cfg) {
        xil_printf("[DP] ERROR: DP config not found\r\n");
        return -1;
    }

    XDpPsu_CfgInitialize(&dp_inst, dp_cfg, dp_cfg->BaseAddr);

    status = XDpPsu_InitializeTx(&dp_inst);
    if (status != XST_SUCCESS) {
        xil_printf("[DP] ERROR: TX init failed (%lu)\r\n", (unsigned long)status);
        return -2;
    }

    /* Set HPD callbacks */
    XDpPsu_SetHpdEventHandler(&dp_inst, dp_hpd_event, &dp_inst);
    XDpPsu_SetHpdPulseHandler(&dp_inst, dp_hpd_pulse, &dp_inst);

    /* --- Audio/Video Buffer Manager --- */
    XAVBuf_CfgInitialize(&avbuf_inst, dp_inst.Config.BaseAddr);

    /* Configure non-live (memory) graphics input, RGBA8888 */
    XAVBuf_SetInputNonLiveVideoFormat(&avbuf_inst, RGBA8888);
    XAVBuf_InputVideoSelect(&avbuf_inst, XAVBUF_VIDSTREAM1_NONLIVE,
                            XAVBUF_VIDSTREAM2_NONLIVE_GFX);
    XAVBuf_ConfigureGraphicsPipeline(&avbuf_inst);

    /* Set pixel clock for 720p @ 60Hz = 74.25 MHz */
    XAVBuf_SetPixelClock(74250000ULL);

    /* --- DPDMA --- */
    dma_cfg = XDpDma_LookupConfig(XPAR_XDPDMA_0_BASEADDR);
    XDpDma_CfgInitialize(&dma_inst, dma_cfg);

    /* Configure the graphics channel framebuffer */
    dma_fb.Address = (UINTPTR)pixel_buf;
    dma_fb.Stride  = SCREEN_W * 4;  /* bytes per scanline */
    dma_fb.LineSize = SCREEN_W * 4;
    dma_fb.Size    = SCREEN_W * SCREEN_H * 4;

    XDpDma_SetGraphicsFormat(&dma_inst, RGBA8888);
    XDpDma_SetQOS(&dma_inst, 11);   /* high QoS for video */

    /* --- Establish DP link --- */
    xil_printf("[DP] Checking for monitor (HPD)...\r\n");

    if (!XDpPsu_IsConnected(&dp_inst)) {
        xil_printf("[DP] No monitor detected — skipping link training\r\n");
        xil_printf("[DP] DPDMA configured but no video output\r\n");
        return 0;
    }

    /* Set 720p timing */
    XDpPsu_CfgMsaUseStandardVideoMode(&dp_inst, XVIDC_VM_1280x720_60_P);
    XDpPsu_SetVideoMode(&dp_inst);

    /* Try to establish link: 2 lanes, HBR (2.7 Gbps) */
    XDpPsu_SetLinkRate(&dp_inst, XDPPSU_LINK_BW_SET_270GBPS);
    XDpPsu_SetLaneCount(&dp_inst, 2);

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

    /* Enable main stream */
    XAVBuf_EnableGraphicsBuffers(&avbuf_inst, 1);
    XDpPsu_EnableMainLink(&dp_inst, 1);

    /* Start DPDMA continuous transfer */
    XDpDma_DisplayGfxFrameBuffer(&dma_inst, &dma_fb);

    /* Flush cache so DPDMA sees the pixel data */
    Xil_DCacheFlushRange((UINTPTR)pixel_buf, PIXEL_BUF_SIZE);

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
    XDpDma_DisplayGfxFrameBuffer(&dma_inst, &dma_fb);
}
