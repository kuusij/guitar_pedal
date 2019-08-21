# guitar_pedal
Digital real-time sound effects project, implemented in VHDL. It can be used as a guitar effect pedal.

This project was written for a setup that includes an ALTERA FPGA evaluation board and a WM8731 audio codec.

The top-level module (effect_top.vhd) includes an I2C master (i2c.vhd), the effect module (audio_ctrl.vhd) and a "processor" (pss.vhd).

The I2C master handles the communication with the codec. This includes writing its configuration registers as well as reading samples from the ADC and sending out samples to DAC.

The effect module gets the input samples, applies the effect algorithm on them and passes the samples on.

The pss module stores the audio codec register addresses. Additionally, it stores the register values that will be written to the codec every time after reset.

