MRuby::Gem::Specification.new 'mruby-bin-picoirb' do |spec|
  spec.license = 'MIT'
  spec.author  = 'HASUMI Hitoshi'
  spec.summary = 'picoirb executable'
  spec.add_dependency 'mruby-pico-compiler', github: 'hasumikin/mruby-pico-compiler'

  mrubyc_dir = "#{build.gem_clone_dir}/mrubyc"
  spec.cc.include_paths << "#{mrubyc_dir}/src"

  mrubyc_srcs = %w(alloc    c_math     c_range   console  keyvalue  rrt0    vm
                   c_array  c_numeric  c_string  error    load      symbol
                   c_hash   c_object   class     global   value   hal_posix/hal)
  mrubyc_objs = mrubyc_srcs.map do |src|
    objfile("#{build_dir}/tools/mrubyc/src/#{src}")
  end

  mrubyc_objs.each_with_index do |mrubyc_obj, index|
    file mrubyc_obj => "#{mrubyc_dir}/src/#{mrubyc_srcs[index]}.c" do |f|
      cc.run f.name, "#{mrubyc_dir}/src/#{mrubyc_srcs[index]}.c"
    end
    file "#{mrubyc_dir}/src/#{mrubyc_srcs[index]}.c" => mrubyc_dir
  end

  directory build.gem_clone_dir

  file mrubyc_dir => build.gem_clone_dir do
    unless Dir.exists? mrubyc_dir
      FileUtils.cd build.gem_clone_dir do
        sh "git clone -b mrubyc3 https://github.com/mrubyc/mrubyc.git"
      end
    end
  end

  mrblib_obj = "#{build_dir}/tools/mrubyc/mrblib.o"

  file mrblib_obj => "#{mrubyc_dir}/src/mrblib.c" do |f|
    cc.run f.name, f.prerequisites.first
  end

  file "#{mrubyc_dir}/src/mrblib.c" => mrubyc_dir do |f|
    mrblib_sources = Dir.glob("#{mrubyc_dir}/mrblib/*.rb").join(' ')
    sh "#{build.mrbcfile} -B mrblib_bytecode -o #{mrubyc_dir}/src/mrblib.c #{mrblib_sources}"
  end


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

  exec = exefile("#{build.build_dir}/bin/picoirb")

  objs = mrubyc_objs +
         pico_compiler_objs +
         [mrblib_obj] +
         picoirb_objs

  file exec => objs do |f|
    build.linker.run f.name, f.prerequisites
  end

  build.bins << 'picoirb'
end
