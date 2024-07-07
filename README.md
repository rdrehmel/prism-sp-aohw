# Prism SP

This is the main repository for the AMD Open Hardware version of the Prism Stream Processor (SP).

The Prism Stream Processor is a soft IP core developed in SystemVerilog.
It is highly modular and can be adapted to process streaming data from
potentially any source to implement a wide variety of use cases. For
example, it can be used to replace the DMA engine of an Ethernet
controller, collect statistics on througput, provide packet filtering,
act as a research and teaching platform on I/O device design, or anything
you choose to.
It it based on a flexible processing pipeline in which each stage can be
either a custom HDL module or a RISC-V processor core extended with a
variety of custom instructions.
