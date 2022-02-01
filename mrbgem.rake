MRuby::Gem::Specification.new 'mruby-bin-picoirb' do |spec|
  spec.license = 'MIT'
  spec.author  = 'HASUMI Hitoshi'
  spec.summary = 'picoirb executable'
  spec.add_dependency 'mruby-pico-compiler', github: 'hasumikin/mruby-pico-compiler'
  spec.add_dependency 'mruby-mrubyc', github: 'hasumikin/mruby-mrubyc'

  spec.cc.include_paths << "#{build.gems['mruby-mrubyc'].clone.dir}/repos/mrubyc/src"

  pico_compiler_srcs = %w(common compiler dump generator mrbgem my_regex
                          node regex scope stream token tokenizer)
  pico_compiler_objs = pico_compiler_srcs.map do |name|
    objfile("#{build.gems['mruby-pico-compiler'].build_dir}/src/#{name}")
  end

  picoirb_mrblib_rbs = Dir.glob("#{dir}/tools/picoirb/*.rb")
  picoirb_mrblib_srcs = picoirb_mrblib_rbs.map do |rb|
    rb.pathmap("%X.c")
  end
  picoirb_mrblib_srcs.each do |src|
    file src => src.pathmap("%X.rb") do |f|
      sh "#{build.mrbcfile} -B #{f.name.pathmap("%n")} -o #{f.name} #{f.prerequisites.first}"
    end
  end

  picoirb_srcs = %w(picoirb sandbox).map{ |s| "#{dir}/tools/picoirb/#{s}.c" }
  picoirb_objs = picoirb_srcs.map do |picoirb_src|
    objfile(picoirb_src.pathmap("#{build_dir}/tools/picoirb/%n"))
  end
  picoirb_objs.each_with_index do |picoirb_obj, index|
    file picoirb_srcs[index] => picoirb_mrblib_srcs
    file picoirb_obj => picoirb_srcs[index] do |f|
      cc.run f.name, picoirb_srcs[index]
    end
  end

  mrubyc_dir = "#{build.gems['mruby-mrubyc'].dir}/repos/mrubyc"
  mrblib_obj = "#{build.gems['mruby-mrubyc'].build_dir}/src/mrblib.o"
  file mrblib_obj => "#{mrubyc_dir}/src/mrblib.c" do |f|
    cc.run f.name, f.prerequisites.first
  end

  file "#{mrubyc_dir}/src/mrblib.c" do |f|
    mrblib_sources = Dir.glob("#{mrubyc_dir}/mrblib/*.rb").join(' ')
    sh "#{build.mrbcfile} -B mrblib_bytecode -o #{mrubyc_dir}/src/mrblib.c #{mrblib_sources}"
  end

  exec = exefile("#{build.build_dir}/bin/picoirb")

  file exec => pico_compiler_objs + [mrblib_obj] + picoirb_objs do |f|
    mrubyc_objs = Dir.glob("#{build.gems['mruby-mrubyc'].build_dir}/src/**/*.o").reject do |o|
      o.end_with? "mrblib.o"
    end
    build.linker.run f.name, f.prerequisites + mrubyc_objs
  end

  build.bins << 'picoirb'
end
