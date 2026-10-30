#include <linux/module.h>
#include <linux/kallsyms.h>
#include <linux/platform_device.h>
#include <linux/pinctrl/machine.h>
#include <linux/pinctrl/pinconf-generic.h>
#include <sound/soc.h>

/*
 * The machine driver linked into kernel #27 asks for a codec named
 * tfa98xx.5-0036 and for pinctrl states mi2s-active, quat_mi2s_active
 * and quat_aux_active. This phone's amplifier is a TFA9887 at i2c-6
 * address 0x34, driven later from userspace, and its device tree names
 * the same pins pri_mi2s-active and quat_mi2s-active. This module only
 * supplies the names the machine driver looks up. It does not talk to
 * the amplifier.
 */

#define PINCTRL_DEV "fd510000.pinctrl"
#define SOUND_DEV "fe034000.sound"

static unsigned long cfg_pri_sleep[] = {
	PIN_CONF_PACKED(PIN_CONFIG_DRIVE_STRENGTH, 2),
	PIN_CONF_PACKED(PIN_CONFIG_BIAS_PULL_DOWN, 1),
	PIN_CONF_PACKED(PIN_CONFIG_INPUT_ENABLE, 1),
};
static unsigned long cfg_pri_active[] = {
	PIN_CONF_PACKED(PIN_CONFIG_DRIVE_STRENGTH, 2),
	PIN_CONF_PACKED(PIN_CONFIG_BIAS_DISABLE, 0),
	PIN_CONF_PACKED(PIN_CONFIG_OUTPUT, 1),
};
static unsigned long cfg_pri_sd_active[] = {
	PIN_CONF_PACKED(PIN_CONFIG_DRIVE_STRENGTH, 2),
	PIN_CONF_PACKED(PIN_CONFIG_BIAS_DISABLE, 0),
};
static unsigned long cfg_quat_sleep[] = {
	PIN_CONF_PACKED(PIN_CONFIG_DRIVE_STRENGTH, 2),
	PIN_CONF_PACKED(PIN_CONFIG_BIAS_PULL_DOWN, 1),
};
static unsigned long cfg_quat_active[] = {
	PIN_CONF_PACKED(PIN_CONFIG_DRIVE_STRENGTH, 8),
	PIN_CONF_PACKED(PIN_CONFIG_BIAS_DISABLE, 0),
	PIN_CONF_PACKED(PIN_CONFIG_OUTPUT, 1),
};
static unsigned long cfg_quat_sd_active[] = {
	PIN_CONF_PACKED(PIN_CONFIG_DRIVE_STRENGTH, 8),
	PIN_CONF_PACKED(PIN_CONFIG_BIAS_DISABLE, 0),
};
static unsigned long cfg_aux_active[] = {
	PIN_CONF_PACKED(PIN_CONFIG_DRIVE_STRENGTH, 8),
	PIN_CONF_PACKED(PIN_CONFIG_BIAS_DISABLE, 0),
	PIN_CONF_PACKED(PIN_CONFIG_OUTPUT, 1),
};
static unsigned long cfg_aux_sd_active[] = {
	PIN_CONF_PACKED(PIN_CONFIG_DRIVE_STRENGTH, 8),
	PIN_CONF_PACKED(PIN_CONFIG_BIAS_DISABLE, 0),
};

static struct pinctrl_map maps[] = {
	/* mi2s-active: same pins as the device tree's pri_mi2s-active */
	PIN_MAP_MUX_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			  "pri_mi2s_active", "pri_mi2s_active-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			      "pri_mi2s_active", cfg_pri_active),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			  "pri_mi2s_sd0_active", "pri_mi2s_sd0_active-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			      "pri_mi2s_sd0_active", cfg_pri_sd_active),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			  "quat_mi2s", "quat_mi2s-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			      "quat_mi2s", cfg_quat_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			  "quat_mi2s_sd0", "quat_mi2s_sd0-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			      "quat_mi2s_sd0", cfg_quat_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			  "quat_mi2s_sd1", "quat_mi2s_sd1-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			      "quat_mi2s_sd1", cfg_quat_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			  "pmx_sec_aux_pcm_sleep", "pmx_sec_aux_pcm_sleep-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			      "pmx_sec_aux_pcm_sleep", cfg_pri_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			  "pmx_sec_aux_pcm_din_sleep", "pmx_sec_aux_pcm_din_sleep-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "mi2s-active", PINCTRL_DEV,
			      "pmx_sec_aux_pcm_din_sleep", cfg_pri_sleep),

	/* quat_mi2s_active: same pins as the device tree's quat_mi2s-active */
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			  "pri_mi2s_sleep", "pri_mi2s_sleep-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			      "pri_mi2s_sleep", cfg_pri_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			  "pri_mi2s_sd0_sleep", "pri_mi2s_sd0_sleep-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			      "pri_mi2s_sd0_sleep", cfg_pri_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			  "quat_mi2s", "quat_mi2s-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			      "quat_mi2s", cfg_quat_active),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			  "quat_mi2s_sd0", "quat_mi2s_sd0-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			      "quat_mi2s_sd0", cfg_quat_sd_active),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			  "quat_mi2s_sd1", "quat_mi2s_sd1-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			      "quat_mi2s_sd1", cfg_quat_sd_active),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			  "pmx_sec_aux_pcm_sleep", "pmx_sec_aux_pcm_sleep-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			      "pmx_sec_aux_pcm_sleep", cfg_pri_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			  "pmx_sec_aux_pcm_din_sleep", "pmx_sec_aux_pcm_din_sleep-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_mi2s_active", PINCTRL_DEV,
			      "pmx_sec_aux_pcm_din_sleep", cfg_pri_sleep),

	/* quat_aux_active: secondary PCM, only so the lookup succeeds */
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			  "pri_mi2s_sleep", "pri_mi2s_sleep-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			      "pri_mi2s_sleep", cfg_pri_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			  "pri_mi2s_sd0_sleep", "pri_mi2s_sd0_sleep-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			      "pri_mi2s_sd0_sleep", cfg_pri_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			  "quat_mi2s", "quat_mi2s-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			      "quat_mi2s", cfg_quat_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			  "quat_mi2s_sd0", "quat_mi2s_sd0-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			      "quat_mi2s_sd0", cfg_quat_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			  "quat_mi2s_sd1", "quat_mi2s_sd1-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			      "quat_mi2s_sd1", cfg_quat_sleep),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			  "pmx_sec_aux_pcm_active", "pmx_sec_aux_pcm_active-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			      "pmx_sec_aux_pcm_active", cfg_aux_active),
	PIN_MAP_MUX_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			  "pmx_sec_aux_pcm_din_active", "pmx_sec_aux_pcm_din_active-func"),
	PIN_MAP_CONFIGS_GROUP(SOUND_DEV, "quat_aux_active", PINCTRL_DEV,
			      "pmx_sec_aux_pcm_din_active", cfg_aux_sd_active),
};

static int (*pinctrl_register_mappings_fn)(const struct pinctrl_map *, unsigned);

static struct snd_soc_dai_driver tfa_stub_dai = {
	.name = "tfa98xx_codec",
	.playback = {
		.stream_name = "Playback",
		.channels_min = 1,
		.channels_max = 8,
		.rates = SNDRV_PCM_RATE_8000_192000,
		.formats = SNDRV_PCM_FMTBIT_S16_LE | SNDRV_PCM_FMTBIT_S24_LE,
	},
};

static struct snd_soc_codec_driver tfa_stub_codec;

static int tfa_stub_probe(struct platform_device *pdev)
{
	return snd_soc_register_codec(&pdev->dev, &tfa_stub_codec,
				      &tfa_stub_dai, 1);
}

static int tfa_stub_remove(struct platform_device *pdev)
{
	snd_soc_unregister_codec(&pdev->dev);
	return 0;
}

static struct platform_driver tfa_stub_driver = {
	.probe = tfa_stub_probe,
	.remove = tfa_stub_remove,
	.driver = {
		.name = "tfa98xx.5-0036",
		.owner = THIS_MODULE,
	},
};

static struct platform_device *tfa_stub_dev;

static int __init tfa_stub_init(void)
{
	int ret;

	pinctrl_register_mappings_fn = (void *)kallsyms_lookup_name(
		"pinctrl_register_mappings");
	if (!pinctrl_register_mappings_fn)
		return -ENOENT;
	ret = pinctrl_register_mappings_fn(maps, ARRAY_SIZE(maps));
	if (ret)
		return ret;

	ret = platform_driver_register(&tfa_stub_driver);
	if (ret)
		return ret;
	tfa_stub_dev = platform_device_register_simple("tfa98xx.5-0036",
						       -1, NULL, 0);
	if (IS_ERR(tfa_stub_dev)) {
		ret = PTR_ERR(tfa_stub_dev);
		platform_driver_unregister(&tfa_stub_driver);
		return ret;
	}
	return 0;
}

static void __exit tfa_stub_exit(void)
{
	platform_device_unregister(tfa_stub_dev);
	platform_driver_unregister(&tfa_stub_driver);
}

module_init(tfa_stub_init);
module_exit(tfa_stub_exit);

MODULE_DESCRIPTION("Names the sambar sound card needs in order to probe");
MODULE_LICENSE("GPL v2");
