/*
 * Output a static picture to 4D Systems 4.3" TFT LCD.
 */
.syntax unified

cm_per_base                 = 0x44e00000
cm_per_lcdc_clkctrl         = 0x18
cm_per_epwmss1_clkctrl      = 0xcc
cm_wkup_base                = 0x44e00400
cm_wkup_idlest_dpll_disp    = 0x48
cm_wkup_clksel_dpll_disp    = 0x54
cm_wkup_clkmode_dpll_disp   = 0x98
cm_dpll_base                = 0x44e00500

lcdc_base                   = 0x4830e000
lcdc_ctrl                   = 0x04
lcdc_raster_ctrl            = 0x28
lcdc_raster_timing_0        = 0x2c
lcdc_raster_timing_1        = 0x30
lcdc_raster_timing_2        = 0x34
lcdc_dma_ctrl               = 0x40
lcdc_dma_fb0_base           = 0x44
lcdc_dma_fb0_ceiling        = 0x48
lcdc_sysconfig              = 0x54
lcdc_irqenable_set          = 0x60
lcdc_irqenable_clear        = 0x64
lcdc_clkc_enable            = 0x6c

ctrl_base                   = 0x44e10000
ctrl_pwmss_ctrl             = 0x664
ctrl_conf_mcasp0_fsr        = 0x9a4
ctrl_conf_lcd_data0         = 0x8a0
ctrl_conf_gpmc_a2           = 0x848

gpio3_base                  = 0x481ae000
gpio_oe                     = 0x134
gpio_cleardataout           = 0x190
gpio_setdataout             = 0x194

epwm1_base                  = 0x48302200
epwm_tbctl                  = 0x00
epwm_tbprd                  = 0x0a
epwm_cmpahr                 = 0x10
epwm_cmpa                   = 0x12
epwm_aqctla                 = 0x16

lcds_width                  = 480
lcds_height                 = 272

.text
.global start
start:
    /*****************************************
     * Configure pins
     *****************************************/
    r_ctrl_base .req r0
    ldr r_ctrl_base, =ctrl_base

    /* Enable brightness control PWM output */
    mov r1, 0x6
    str r1, [r_ctrl_base, ctrl_conf_gpmc_a2]
    /* Enable brightness control PWM clock */
    mov r1, 2
    str r1, [r_ctrl_base, ctrl_pwmss_ctrl]

    /* Enable GPIO3_19 output for display-on signal */
    mov r1, 0xF
    str r1, [r_ctrl_base, ctrl_conf_mcasp0_fsr]
    .unreq r_ctrl_base

    /*
     * Configure LCD controller pins:
     * lcd_pixel_o[15:0]    - data bus output   - pullup/pulldown disabled
     * lcd_cp               - pixel clock       - pulled down
     * lcd_lp               - hsync             - pulled down
     * lcd_fp               - vsync             - pulled down
     * lcd_ac               - latch enable      - pulled down
     */
    /*
     * Linux pin configuration:
     *
     * 44e108a0: 00000008 00000008 00000008 00000008
     * 44e108b0: 00000008 00000008 00000008 00000008
     * 44e108c0: 00000008 00000008 00000008 00000008
     * 44e108d0: 00000008 00000008 00000008 00000008
     * 44e108e0: 00000000 00000000 00000000 00000000
     */
    r_ctrl_conf_lcd .req r0
    /* Configure data pins */
    ldr r_ctrl_conf_lcd, =ctrl_base + ctrl_conf_lcd_data0
    mov r1, 0x8
    mov r2, 16
1:  str r1, [r_ctrl_conf_lcd], 4
    subs r2, r2, 1
    bne 1b
    /* Configure timing pins */
    mov r1, 0x0
    mov r2, 4
1:  str r1, [r_ctrl_conf_lcd], 4
    subs r2, r2, 1
    bne 1b
    .unreq r_ctrl_conf_lcd

    /*******************************************
     * Configure and enable clocks
     *******************************************/
    /*
     * Configure display PLL
     */
    r_cm_wkup_base .req r0
    ldr r_cm_wkup_base, =cm_wkup_base
    /* Switch DPLL to MN bypass mode */
    mov r1, 0x4     /* DPLL_MN_BYP_MODE */
    str r1, [r_cm_wkup_base, cm_wkup_clkmode_dpll_disp]

    /* Wait for DPLL to switch to bypass */
1:  ldr r1, [r_cm_wkup_base, cm_wkup_idlest_dpll_disp]
    tst r1, 1 << 8  /* ST_MN_BYPASS */
    beq 1b

    /* Set DPLL multiplier and divider factors */
    ldr r1, =0x303  /* Glanced from the Linux setup */
    str r1, [r_cm_wkup_base, cm_wkup_clksel_dpll_disp]

    /* Switch DPLL to lock mode */
    mov r1, 0x7     /* DPLL_LOCK_MODE */
    str r1, [r_cm_wkup_base, cm_wkup_clkmode_dpll_disp]

    /* Wait for DPLL to lock */
1:  ldr r1, [r_cm_wkup_base, cm_wkup_idlest_dpll_disp]
    tst r1, 1 << 0  /* ST_DPLL_CLK */
    beq 1b
    .unreq r_cm_wkup_base

    /*
     * Enable LCD controller and EPWMSS1 modules
     */
    r_cm_per_base .req r0
    ldr r_cm_per_base, =cm_per_base

    /* Enable LCDC module */
    mov r1, 0x2
    str r1, [r_cm_per_base, cm_per_lcdc_clkctrl]
    /* Wait for the module to become functional */
1:  ldr r1, [r_cm_per_base, cm_per_lcdc_clkctrl]
    tst r1, 0x7 << 16   /* STBYST and IDLEST */
    bne 1b

    /* Enable EPWMSS1 module (for brightness control) */
    mov r1, 0x2
    str r1, [r_cm_per_base, cm_per_epwmss1_clkctrl]
    /* Wait for the module to become functional */
1:  ldr r1, [r_cm_per_base, cm_per_epwmss1_clkctrl]
    tst r1, 0x3 << 16   /* IDLEST */
    bne 1b
    .unreq r_cm_per_base

    /*******************************************
     * Configure misc requisites
     *******************************************/
    /*
     * Turn the display on
     */
    /* Enable gpio3_19 output and set it on */
    r_gpio_base .req r0
    ldr r_gpio_base, =gpio3_base
    mvn r1, (1 << 19)
    str r1, [r_gpio_base, gpio_oe]
    mvn r1, r1
    str r1, [r_gpio_base, gpio_setdataout]
    .unreq r_gpio_base

    /*
     * Turn the backlight on - configure ehrpwm1a output for 50% duty
     */
    r_epwm_base .req r0
    ldr r_epwm_base, =epwm1_base
    /* Disable PWM stopping on debug events */
    mov r1, 0xc000
    strh r1, [r_epwm_base, epwm_tbctl]
    /* Set period */
    ldr r1, =0xc350
    strh r1, [r_epwm_base, epwm_tbprd]
    /* Set compare A value to 50% of the period */
    mov r1, 0x0
    strh r1, [r_epwm_base, epwm_cmpahr]
    ldr r1, =0x61a8
    strh r1, [r_epwm_base, epwm_cmpa]
    /* Configure A output actions */
    mov r1, 0x1a    /* CNT==0 -> high, CNT==PRD -> high, CAU -> low */
    strh r1, [r_epwm_base, epwm_aqctla]
    .unreq r_epwm_base

    /******************************************************
     * Generate framebuffer contents
     *****************************************************/
    r_fb_palette .req r0
    ldr r_fb_palette, =fb_palette

    /*
     * Generate palette.
     * Assume DMA endianness matches CPU endianness.
     */
    /* Store 8 BPP marker and black color in entry 0 */
    mov r2, 0x3000
    strh r2, [r_fb_palette], 2

    /* Generate HSV(0-360, 1, 1) palette, 90 colors. */
    mov r1, 0
1:
    /* 0°   0-14:    R~ G/ B_ */
    cmp r1, 14
    movls r2, 0xF00
    bfils r2, r1, 4, 4
    bls 2f
    /* 60°  15-29:   R\ G~ B_ */
    cmp r1, 29
    movls r2, 0x0F0
    rsbls r3, r1, 30
    bfils r2, r3, 8, 4
    bls 2f
    /* 120° 30-44:   R_ G~ B/ */
    cmp r1, 44
    movls r2, 0x0F0
    subls r3, r1, 30
    bfils r2, r3, 0, 4
    bls 2f
    /* 180° 45-59:   R_ G\ B~ */
    cmp r1, 59
    movls r2, 0x00F
    rsbls r3, r1, 60
    bfils r2, r3, 4, 4
    bls 2f
    /* 240° 60-74:   R/ G_ B~ */
    cmp r1, 74
    movls r2, 0x00F
    subls r3, r1, 60
    bfils r2, r3, 8, 4
    bls 2f
    /* 320° 75-89:  R~ G_ B\ */
    cmp r1, 89
    movls r2, 0xF00
    rsbls r3, r1, 90
    bfils r2, r3, 0, 4
    bhi 3f
2:
    strh r2, [r_fb_palette], 2
    add r1, r1, 1
    b 1b
3:
    .unreq r_fb_palette

    /*
     * Generate picture - a horizontal color swatch.
     */
    r_fb_picture    .req r0
    r_line          .req r1
    r_pixel         .req r2
    r_color         .req r3

    ldr r_fb_picture, =fb_picture
    mov r_line, lcds_height
1:
    mov r_pixel, lcds_width
2:
    mov r_color, 1
3:
    strb r_color, [r_fb_picture], 1
    subs r_pixel, r_pixel, 1
    beq 4f
    tst r_pixel, 0x3
    bne 3b
    add r_color, r_color, 1
    cmp r_color, 90
    bhi 2b
    b 3b
4:
    subs r_line, r_line, 1
    bne 1b

    .unreq r_fb_picture
    .unreq r_line
    .unreq r_pixel
    .unreq r_color

    /******************************************************
     * Configure LCD controller
     *****************************************************/
    r_lcdc_base .req r0
    ldr r_lcdc_base, =lcdc_base

    /*
     * Linux driver register values
     *
     * 00 PID                   4f201000
     * 04 CTRL                  00000201
     * 08 LIDD_CTRL             00000000
     * 0c                       00000000
     * 10 LIDD_CS0_CONF         00440044
     * 14 LIDD_CS0_ADDR         00000000
     * 18 LIDD_CS0_DATA         00000000
     * 1c LIDD_CS1_CONF         00440044
     * 20 LIDD_CS1_ADDR         00000000
     * 24 LIDD_CS1_DATA         00000000
     * 28 RASTER_CTRL           00a00081
     * 2c RASTER_TIMING_0       2a070dd0
     * 30 RASTER_TIMING_1       0c04250f
     * 34 RASTER_TIMING_2       0230ff00
     * 38 RASTER_SUBPANEL       00000000
     * 3c RASTER_SUBPANEL2      00000000
     * 40 LCDDMA_CTRL           00000041
     * 44 LCDDMA_FB0_BASE       9cc00000
     * 48 LCDDMA_FB0_CEILING    9cc3fc00
     * 4c LCDDMA_FB1_BASE       9cc00000
     * 50 LCDDMA_FB1_CEILING    9cc3fc00
     * 54 SYSCONFIG             00000014
     * 58 IRQSTATUS_RAW         00000002
     * 5c IRQSTATUS             00000000
     * 60 IRQENABLE_SET         00000321
     * 64 IRQENABLE_CLEAR       00000321
     * 68                       00000000
     * 6c CLKC_ENABLE           00000007
     * 70 CLKC_RESET            00000000
     */

    /* Enable DMA and core submodule clocks, leave LIDD submodule disabled */
    mov r1, 0x5
    str r1, [r_lcdc_base, lcdc_clkc_enable]

    /*
     * Configure horizontal timing (glanced from Linux driver setup):
     * horizontal back porch - 43 pixel clock periods,
     * horizontal front porch - 8 pixel clock periods,
     * horizontal sync pulse width - 4 pixel clock periods,
     * pixels per line - 480.
     */
    ldr r1, =0x2a070dd0 /* hbp: 0x2a, hfp: 0x07, hsw: 0x03, ppllsb: 0x1d */
    str r1, [r_lcdc_base, lcdc_raster_timing_0]

    /*
     * Configure vertical timing (glanced from Linux driver setup):
     * vertical back porch - 12 line clock periods,
     * vertical front porch - 4 line clock periods,
     * vertical sync pulse width - 10 line clock periods,
     * lines per panel - 272.
     */
    ldr r1, =0x0c04250f /* vbp: 0x0c, vfp: 0x04, vsw: 0x09, lpp: 0x10f */
    str r1, [r_lcdc_base, lcdc_raster_timing_1]

    /*
     * Configure misc timing (glanced from Linux driver setup):
     * enable hsync/vsync pixel clock control to have lcdc_lp and lcdc_fp driven
     * on the rising edge of pixel clock,
     * invert hsync (lcdc_lp pin is active low and inactive high),
     * invert vsync (lcdc_fp pin is active low and inactive high),
     * set AC bias pin frequency to invert once per 255 line clocks (seems to
     * be unnecessary for TFT).
     */
    ldr r1, =0x0230ff00 /* phsvs_on_off: 1, ihs: 1, ivs: 1, acb: 0xff */
    str r1, [r_lcdc_base, lcdc_raster_timing_2]

    /*
     * Configure DMA:
     * burst transfer size - 16 * 32 bits (maximum),
     * one frame buffer (FB0 only).
     */
    mov r1, 0x40 /* burst_size: 4, frame_mode: 0 */
    str r1, [r_lcdc_base, lcdc_dma_ctrl]

    /*
     * Set framebuffer 0 base and ceiling
     */
    ldr r1, =fb_base
    str r1, [r_lcdc_base, lcdc_dma_fb0_base]
    ldr r1, =fb_ceiling
    str r1, [r_lcdc_base, lcdc_dma_fb0_ceiling]

    /* Disable idle and stand-by modes */
    mov r1, 0x14 /* standbymode: 1, idlemode: 1 */
    str r1, [r_lcdc_base, lcdc_sysconfig]

    /* Disable all interrupts */
    ldr r1, =0x3ff
    str r1, [r_lcdc_base, lcdc_irqenable_clear]

    /* Enable raster mode and set clock divisor */
    ldr r1, =0x201 /* clkdiv: 2, modesel: 1 */
    str r1, [r_lcdc_base, lcdc_ctrl]

    /*
     * Configure raster mode and enable LCD controller:
     * set paletted active display operation (TFT),
     * always load both palette and picture,
     * use alternate signal mapping (4/4/4 -> 5/6/5).
     */
    ldr r1, =0x800081 /* tftmap: 1, lcdtft: 1, lcden: 1 */
    str r1, [r_lcdc_base, lcdc_raster_ctrl]

    .unreq r_lcdc_base

    /*
     * Return and hope the framebuffer is not overwritten by U-boot.
     */
    bx lr

.data
/*
 * Framebuffer, must be last
 */
.align 2
.global fb_base
fb_base:
.global fb_palette
fb_palette:
.global fb_picture
fb_picture = fb_palette + 512
.global fb_ceiling
fb_ceiling = fb_picture + lcds_width * lcds_height
