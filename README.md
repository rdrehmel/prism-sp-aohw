# Prism SP

This is the main repository for the AMD Open Hardware version of the Prism Stream Processor (SP).
The Prism SP combines a flexible processing pipeline in which a heavily modified Taiga processor core can be inserted.
The Taiga core sources were forked after commit _e8cd051c40817a88fa825f4ae7069c18ca057126_.
Because of the specific use case of the Stream Processor and the maturity of the Taiga core sources,
it is expected that we will only merge important fixes from the Taiga core into the SP while the SP is under development.
Currently the Prism SP interfaces to a GEM peripheral found on AMD Zynq UltraScale+ MPSoC and AMD Versal chips.

The Taiga core was developed by Eric Matthews et al. at Simon Fraser University.
See https://gitlab.com/sfu-rcl/Taiga, a repository which hosts the Taiga processor core.
Also see https://gitlab.com/sfu-rcl/taiga-project, a larger wrapper repository which imports the Taiga core, a preconfigured RISC-V toolchain/libraries and supplies scripts to build them.

The Prism SP code uses the same license (Apache 2.0) as the Taiga core.
