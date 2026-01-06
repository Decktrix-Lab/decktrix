/*******************************************************************
 *
 * main.c - LVGL simulator for GNU/Linux
 *
 * Based on the original file from the repository
 *
 * @note eventually this file won't contain a main function and will
 * become a library supporting all major operating systems
 *
 * To see how each driver is initialized check the
 * 'src/lib/display_backends' directory
 *
 * - Clean up
 * - Support for multiple backends at once
 *   2025 EDGEMTech Ltd.
 *
 * Author: EDGEMTech Ltd, Erik Tagirov (erik.tagirov@edgemtech.ch)
 *
 ******************************************************************/
#include <unistd.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lvgl/lvgl.h"
#include "lvgl/demos/lv_demos.h"

#include "src/lib/driver_backends.h"
#include "src/lib/simulator_util.h"
#include "src/lib/simulator_settings.h"

/* Internal functions */
static void configure_simulator(int argc, char ** argv);
static void print_lvgl_version(void);
static void print_usage(void);

/* contains the name of the selected backend if user
 * has specified one on the command line */
static char * selected_backend;

/* Global simulator settings, defined in lv_linux_backend.c */
extern simulator_settings_t settings;

/* DMM section */
static lv_style_t style_grid;
static lv_style_t style_btn_mode;
static lv_style_t style_lbl_mode_selected;
static lv_style_t style_img_mode_selected;
static lv_style_t style_btn_ac_dc_selected;
static lv_style_t style_lbl_measurments;
static lv_style_t style_lbl_indicators;

static lv_obj_t * dmm_selected_mode;
static lv_obj_t * dmm_selected_ac_dc;

/**
 * @brief Print LVGL version
 */
static void print_lvgl_version(void)
{
    fprintf(stdout, "%d.%d.%d-%s\n",
            LVGL_VERSION_MAJOR,
            LVGL_VERSION_MINOR,
            LVGL_VERSION_PATCH,
            LVGL_VERSION_INFO);
}

/**
 * @brief Print usage information
 */
static void print_usage(void)
{
    fprintf(stdout, "\nlvglsim [-V] [-B] [-f] [-m] [-b backend_name] [-W window_width] [-H window_height]\n\n");
    fprintf(stdout, "-V print LVGL version\n");
    fprintf(stdout, "-B list supported backends\n");
    fprintf(stdout, "-f fullscreen\n");
    fprintf(stdout, "-m maximize\n");
}

/**
 * @brief Configure simulator
 * @description process arguments received by the program to select
 * appropriate options
 * @param argc the count of arguments in argv
 * @param argv The arguments
 */
static void configure_simulator(int argc, char ** argv)
{
    int opt = 0;

    selected_backend = NULL;
    driver_backends_register();

    const char * env_w = getenv("LV_SIM_WINDOW_WIDTH");
    const char * env_h = getenv("LV_SIM_WINDOW_HEIGHT");
    /* Default values */
    settings.window_width = atoi(env_w ? env_w : "800");
    settings.window_height = atoi(env_h ? env_h : "480");

    /* Parse the command-line options. */
    while((opt = getopt(argc, argv, "b:fmW:H:BVh")) != -1) {
        switch(opt) {
            case 'h':
                print_usage();
                exit(EXIT_SUCCESS);
                break;
            case 'V':
                print_lvgl_version();
                exit(EXIT_SUCCESS);
                break;
            case 'B':
                driver_backends_print_supported();
                exit(EXIT_SUCCESS);
                break;
            case 'b':
                if(driver_backends_is_supported(optarg) == 0) {
                    die("error no such backend: %s\n", optarg);
                }
                selected_backend = strdup(optarg);
                break;
            case 'f':
                settings.fullscreen = true;
                break;
            case 'm':
                settings.maximize = true;
                break;
            case 'W':
                settings.window_width = atoi(optarg);
                break;
            case 'H':
                settings.window_height = atoi(optarg);
                break;
            case ':':
                print_usage();
                die("Option -%c requires an argument.\n", optopt);
                break;
            case '?':
                print_usage();
                die("Unknown option -%c.\n", optopt);
        }
    }
}

static void configure_styles(void)
{
    static int32_t col_dsc[] = {LV_GRID_FR(25), LV_GRID_FR(25), LV_GRID_FR(25), LV_GRID_FR(25), LV_GRID_TEMPLATE_LAST};
    static int32_t row_dsc[] = {LV_GRID_FR(33), LV_GRID_FR(34), LV_GRID_FR(33), LV_GRID_TEMPLATE_LAST};

    LV_FONT_DECLARE(dhurjati_70);
    LV_FONT_DECLARE(dhurjati_140);
    LV_FONT_DECLARE(digital7_230);

    lv_style_init(&style_grid);
    lv_style_set_pad_row(&style_grid, 1);
    lv_style_set_pad_column(&style_grid, 1);
    lv_style_set_pad_all(&style_grid, 0);
    lv_style_set_grid_column_dsc_array(&style_grid, col_dsc);
    lv_style_set_grid_row_dsc_array(&style_grid, row_dsc);
    lv_style_set_height(&style_grid, lv_pct(100));
    lv_style_set_width(&style_grid, lv_pct(100));
    lv_style_set_align(&style_grid, LV_ALIGN_CENTER);
    lv_style_set_layout(&style_grid, LV_LAYOUT_GRID);

    lv_style_init(&style_btn_mode);
    lv_style_set_radius(&style_btn_mode, 0);
    lv_style_set_bg_color(&style_btn_mode, lv_color_hex(0x1d1b1b));
    lv_style_set_text_font(&style_btn_mode, &dhurjati_140);

    lv_style_init(&style_lbl_mode_selected);
    lv_style_set_bg_color(&style_lbl_mode_selected, lv_color_hex(0x3C7ACC));
    lv_style_set_bg_opa(&style_lbl_mode_selected, LV_OPA_100);
    lv_style_set_pad_all(&style_lbl_mode_selected, 20);
    lv_style_set_radius(&style_lbl_mode_selected, 20);
    lv_style_set_text_color(&style_lbl_mode_selected, lv_color_hex(0x1d1b1b));
    lv_style_set_align(&style_lbl_mode_selected, LV_ALIGN_CENTER);

    lv_style_init(&style_img_mode_selected);
    lv_style_copy(&style_img_mode_selected, &style_lbl_mode_selected);
    lv_style_set_image_recolor(&style_img_mode_selected, lv_color_hex(0x1d1b1b));
    lv_style_set_image_recolor_opa(&style_img_mode_selected, LV_OPA_100);

    lv_style_init(&style_btn_ac_dc_selected);
    lv_style_set_bg_color(&style_btn_ac_dc_selected, lv_color_white());
    lv_style_set_text_color(&style_btn_ac_dc_selected, lv_color_hex(0x1d1b1b));

    lv_style_init(&style_lbl_measurments);
    lv_style_set_text_font(&style_lbl_measurments, &digital7_230);
    lv_style_set_text_color(&style_lbl_measurments, lv_color_hex(0xFFBB00));

    lv_style_init(&style_lbl_indicators);
    lv_style_set_bg_color(&style_lbl_indicators, lv_color_hex(0xA3363F));
    lv_style_set_bg_opa(&style_lbl_indicators, LV_OPA_100);
    lv_style_set_pad_all(&style_lbl_indicators, 5);
    lv_style_set_pad_left(&style_lbl_indicators, 20);
    lv_style_set_pad_right(&style_lbl_indicators, 20);
    lv_style_set_radius(&style_lbl_indicators, 20);
    lv_style_set_text_color(&style_lbl_indicators, lv_color_hex(0xFFFFFF));
    lv_style_set_text_font(&style_lbl_indicators, &dhurjati_70);
}

static lv_obj_t * cell_selected_event(lv_event_t * e, lv_obj_t * selected_cell)
{
    lv_event_code_t code = lv_event_get_code(e);
    lv_obj_t * cell      = lv_event_get_target_obj(e);

    if(code != LV_EVENT_VALUE_CHANGED) {
        LV_LOG_ERROR("Unhandled event");
        return selected_cell;
    }

    if(selected_cell) {
        lv_obj_remove_state(selected_cell, LV_STATE_CHECKED);
        lv_obj_add_flag(selected_cell, LV_OBJ_FLAG_CHECKABLE);
    }

    lv_obj_remove_flag(cell, LV_OBJ_FLAG_CHECKABLE);
    selected_cell = cell;

    return selected_cell;
}

static void mode_cell_selected_event(lv_event_t * e)
{
    dmm_selected_mode = cell_selected_event(e, dmm_selected_mode);
}

static void ac_dc_cell_selected_event(lv_event_t * e)
{
    dmm_selected_ac_dc = cell_selected_event(e, dmm_selected_ac_dc);
}

static lv_obj_t * create_mode_cell(lv_obj_t * parent, int col, int row)
{
    lv_obj_t * cell = lv_button_create(parent);
    lv_obj_set_grid_cell(cell, LV_GRID_ALIGN_STRETCH, col, 1, LV_GRID_ALIGN_STRETCH, row, 1);
    lv_obj_add_event_cb(cell, mode_cell_selected_event, LV_EVENT_VALUE_CHANGED, NULL);

    /* Remove default "RED" background when clicking on button */
    lv_obj_remove_style(cell, NULL, LV_STATE_CHECKED);

    lv_obj_add_style(cell, &style_btn_mode, 0);

    /* Propogate events from the button to children so the style will be applied
       on LV_STATE_CHECKED to children as well */
    lv_obj_add_flag(cell, LV_OBJ_FLAG_STATE_TRICKLE);
    lv_obj_add_flag(cell, LV_OBJ_FLAG_CHECKABLE);

    return cell;
}

static void create_mode_cell_label(lv_obj_t * parent, int col, int row, const char * text)
{
    lv_obj_t * cell = create_mode_cell(parent, col, row);

    lv_obj_t * label = lv_label_create(cell);
    lv_label_set_text(label, text);
    lv_obj_add_style(label, &style_lbl_mode_selected, LV_STATE_CHECKED);
    lv_obj_center(label);
}

static void create_mode_cell_icon(lv_obj_t * parent, int col, int row, const lv_image_dsc_t * icon)
{
    lv_obj_t * cell = create_mode_cell(parent, col, row);

    lv_obj_t * img = lv_image_create(cell);
    lv_img_set_src(img, icon);
    lv_obj_add_style(img, &style_img_mode_selected, LV_STATE_CHECKED);
    lv_obj_center(img);
}

static void create_measurments_cell(lv_obj_t * parent, int col, int row)
{
    lv_obj_t * cell = lv_button_create(parent);
    lv_obj_set_grid_cell(cell, LV_GRID_ALIGN_STRETCH, col, 2, LV_GRID_ALIGN_STRETCH, row, 2);
    lv_obj_remove_flag(cell, LV_OBJ_FLAG_CLICKABLE);
    lv_obj_add_style(cell, &style_btn_mode, 0);

    lv_obj_t * label = lv_label_create(cell);
    lv_label_set_text(label, "auto");
    lv_obj_align(label, LV_ALIGN_CENTER, -140, -100);
    lv_obj_add_style(label, &style_lbl_indicators, 0);

    label = lv_label_create(cell);
    lv_label_set_text_fmt(label, "%.2f", 22.15);
    lv_obj_align(label, LV_ALIGN_CENTER, 0, 20);
    lv_obj_add_style(label, &style_lbl_measurments, 0);
}

static void create_ac_dc_cell(lv_obj_t * parent, int col, int row, const char * text)
{
    lv_obj_t * cell = lv_button_create(parent);
    lv_obj_set_grid_cell(cell, LV_GRID_ALIGN_STRETCH, col, 1, LV_GRID_ALIGN_STRETCH, row, 1);
    lv_obj_add_event_cb(cell, ac_dc_cell_selected_event, LV_EVENT_VALUE_CHANGED, NULL);
    lv_obj_add_style(cell, &style_btn_mode, 0);
    lv_obj_add_style(cell, &style_btn_ac_dc_selected, LV_STATE_CHECKED);
    lv_obj_add_flag(cell, LV_OBJ_FLAG_CHECKABLE);

    lv_obj_t * label = lv_label_create(cell);
    lv_label_set_text(label, text);
    lv_obj_center(label);
}

static void setup_dmm_ui(void)
{
    LV_IMAGE_DECLARE(omega_icon);
    LV_IMAGE_DECLARE(continuity_icon);

    configure_styles();

    /*Create a container with grid*/
    lv_obj_t * mode_grid = lv_obj_create(lv_screen_active());
    lv_obj_add_style(mode_grid, &style_grid, 0);

    create_mode_cell_icon(mode_grid, 0, 0, &omega_icon);
    create_measurments_cell(mode_grid, 1, 0);
    create_mode_cell_label(mode_grid, 3, 0, "A");
    create_mode_cell_icon(mode_grid, 0, 1, &continuity_icon);
    create_mode_cell_label(mode_grid, 3, 1, "mA");
    create_mode_cell_label(mode_grid, 0, 2, "kHZ");
    create_ac_dc_cell(mode_grid, 1, 2, "DC");
    create_ac_dc_cell(mode_grid, 2, 2, "AC");
    create_mode_cell_label(mode_grid, 3, 2, "V");
}

/**
 * @brief entry point
 * @description start a demo
 * @param argc the count of arguments in argv
 * @param argv The arguments
 */
int main(int argc, char ** argv)
{
    configure_simulator(argc, argv);

    /* Initialize LVGL. */
    lv_init();

    /* Initialize the configured backend */
    if(driver_backends_init_backend(selected_backend) == -1) {
        die("Failed to initialize display backend");
    }

    /* Enable for EVDEV support */
#if LV_USE_EVDEV
    if(driver_backends_init_backend("EVDEV") == -1) {
        die("Failed to initialize evdev");
    }
#endif

    setup_dmm_ui();

    /* Enter the run loop of the selected backend */
    driver_backends_run_loop();

    return 0;
}
