# embedded_rake
Rake subscript allowing for easy multi-toolchain and multi-configuration building, appropriate for embedded developpement.

- The main goal was to avoid using makefile, that induces headaches for complex project structures.
- The second goal is an experimental approach to the use of rake.

An example + test is provided in the rakefile

To use this library/subscript, you need to "require" the embedded_rake.rb file in your final rakefile

In general, you will probably want to make an intermediate architecture-specific rakefile library, so that your final structure is:

libs/embedded_rake/embedded_rake.rb *<-[require]-* libs/arch???_toolchain/arch???_rake.rb *<-[require]-* projects/project???/rakefile

Additionnal libraries for specific real-world chips are also provided under their own separate repositories, such as STM32, and ESP8266.

## Who is it for ?

- If you dislike or hate make

- If you need to use multiple configurations and multiple toolchains for generating your output binaries

- If your project is simple, but the appropriate architecture rake library already exists, or you feel like creating your own.


## The differences and advantages compared to a makefile:

- You can script whatever you want in ruby, and avoid having to use shell and the makefile syntax.
- That also means: no more weird behavior with spaces, escaping, and all that stuff.
- "include" becomes "require" because ruby.

### Now for the added features:
- When building a binary, you are always in a defined toolchain + config environment: e.g. STM32-SDK/release, STM32-SDK/debug, x86-tests/debug. To know which toolchain + config it should use, embedded_rake uses the output directory structure: you ask for bin/out/STM32-SDK/release/project.bin, it will use the corresponding STM32-SDK toolchain + release config rules.

- Your configuration for each toolchain is stored in a config structure, which makes toolchain inheritance relatively easy (although slightly verbose). A use case is that you have an architecture A, for which chips A1, A2, A3 exist, you can define the basics of your toolchain for the whole architecture A, and then refine it for each chip A1, A2, A3.

- Those configurations are made to coexist in the same rakefile, which means that you can distribute different binaries, but also that you can compile; execute and verify "local" tests that should run on the platform used for building, i.e. In general something x86. Thanks to the structure of embedded_rake, you can now integrate easily your library unit tests into your embedded programming flow.

- Easy color output is provided out of the box.

- Dependency support is provided out of the box.

