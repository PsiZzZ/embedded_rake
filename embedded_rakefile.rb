
require "colorize"

# Infrastructure: prepare the config properties dictionnary
def toolchain(dict)
    $config.nil? && $config = {}

    dict.each { |toolchain,configs|
        $config[toolchain].nil? && $config[toolchain] = {}

        configs.each { |c|
            $config[toolchain][c].nil? && $config[toolchain][c] = {} 
            $config[toolchain][c][:VERBOSE_UTIL] = false
            $config[toolchain][c][:VERBOSE_BUILD] = false
        }
    }
end

def config(conf, hash_or_sym)
    if hash_or_sym.is_a?(Symbol) then
        return $config[conf.split("/")[0]][conf.split("/")[1]][hash_or_sym] 
    end

    if not hash_or_sym.is_a?(Hash) then
        raise "Expecting a Hash (set) or Symbol (get)"
    end

    hash_or_sym.each{ |k, v|
        $config[conf.split("/")[0]][conf.split("/")[1]][k] = v
    }
end


def toolchain_dep(t,c)
    proc do |obj|
        l = []
        d = obj.gsub(/^bin\/obj/, "bin\/obj").gsub(/\..+$/, ".d")
        l += [d]
        begin
            l += open(d).read.gsub(/\\/,"").gsub(/[^:]+: /,"").split
        rescue
        end
        l += ["rakefile"]
        #puts "Deps of #{obj} " + l.to_s
        l
    end
end

def toolchain_config(t,c,e)
    proc do |obj|
        d = obj.gsub(/^bin\/obj\/#{t}\/#{c}/, "src").gsub(/\..+$/, e)
        [d , "rakefile"]
    end
end

def toolchain_global(t,c,e)
    [ toolchain_config(t,c,e), toolchain_dep(t,c) ]
end

def toolchain_ld_config(t,c,e)
    proc do |obj|
        p obj
        d = obj.gsub(/^bin\/out\/#{t}\/#{c}.+/, "bin/obj/#{t}/#{c}")
        p d
        [d , "rakefile"]
    end
end

def toolchain_ld_global(t,c,e)
    [ toolchain_ld_config(t,c,e) ]
end

def sh_config(t,c,e)
    proc do |obj|
        obj.gsub(/^bin\/out\/#{t}\/#{c}/, "bin/out/#{t}/#{c}").gsub(/\..+$/, e)
    end
end

#
def toolchain_config_subdir(t,c,s,e)
    proc do |obj|
        a = obj.gsub(/^bin\/obj\/#{t}\/#{c}\/#{s}/, "src/#{s}").gsub(/\..+$/, e)
    end
end

def action_msg(t,c,target,action,color=:default)
    print (action + (" "*(16-action.length)) +" #{t}/#{c} #{(not target.source.nil?) && target.source || ""} #{(not target.name.nil?) && target.name}" "\n").colorize(color)
end

def action_prepare(t,c,target)
    verbose($config[t][c][:VERBOSE_UTIL]) do
        sh "mkdir -p " + target.name[/(([^\/]+\/)+)/]
        $config[t][c][:VERBOSE_UTIL] && print("\n")
    end
end


def define_rules(t,c,e)
    rule '.o' => toolchain_global(t,c,e) do |target|
        action_msg t, c, target, (e.gsub(/[.]/, "").upcase + "C"), :light_blue
        action_prepare t, c, target
        verbose($config[t][c][:VERBOSE_BUILD]) do
            sh ($config[t][c][(e.gsub(/[.]/, "").upcase + "C").to_sym] + " " + \
                $config[t][c][(e.gsub(/[.]/, "").upcase + "FLAGS").to_sym] + " -o " + target.name + " " + target.source)
            $config[t][c][:VERBOSE_BUILD] && print("\n")
        end
    end

    if not $config[t][c][(e.gsub(/[.]/, "").upcase + "DEPS").to_sym].nil?
        rule '.d' => toolchain_config(t,c,e) do |target|
            action_msg t, c, target, (e.gsub(/[.]/, "").upcase + "DEPS"), :light_black
            action_prepare t, c, target
            verbose($config[t][c][:VERBOSE_BUILD]) do
                sh $config[t][c][(e.gsub(/[.]/, "").upcase + "DEPS").to_sym] + " " + target.name + " " + target.source
                $config[t][c][:VERBOSE_BUILD] && print("\n")
            end
        end
    else
        rule '.d' => toolchain_config(t,c,e) do |target|
            action_prepare t, c, target
            verbose($config[t][c][:VERBOSE_UTIL]) do
                sh "touch " + target.name
                $config[t][c][:VERBOSE_UTIL] && print("\n")
            end
        end
    end
end

def define_ld_rules(t, c, e)
    rule /bin\/out\/#{t}\/#{c}\/.*\.elf/ do |target|
        action_msg 		t, c, target, "LD(ELF)", :light_green
        action_prepare	t, c, target
        verbose($config[t][c][:VERBOSE_BUILD]) do
            sh ($config[t][c]["LD".to_sym] + " " + \
                " -o " + target.name + " " + target.prerequisites.select {|n| n.end_with? e }.join(" ") + " " + $config[t][c]["LDFLAGS".to_sym] )
            $config[t][c][:VERBOSE_BUILD] && print("\n")
        end
    end

    rule /bin\/out\/#{t}\/#{c}\/.*\.a/ do |target|
        action_msg 		t, c, target, "AR", :light_green
        action_prepare	t, c, target
        verbose($config[t][c][:VERBOSE_BUILD]) do
            sh ($config[t][c]["AR".to_sym] + " " + \
                $config[t][c]["ARFLAGS".to_sym] + " " + target.name + " " + target.prerequisites.select {|n| n.end_with? e }.join(" ") )
            $config[t][c][:VERBOSE_BUILD] && print("\n")
        end
    end

end

def file_config(conf, dict)
    dict.each { |k,v|
        file 'bin/out/'+conf+'/'+k => v.map { |x| 'bin/obj/'+conf+'/' + x }
    }
end

def define_exec(t,c,e)
    rule '.out' => sh_config(t, c, e) do |target|
        action_msg t, c, target, "EXEC", :light_yellow
        action_prepare t, c, target
        sh target.source + " > " + target.name
        print "\n"
    end
end

def define_exec_special(t,c,e, special)
    rule '.out' => sh_config(t, c, e) do |target|
        action_msg t, c, target, "EXECSPECIAL", :light_yellow
        action_prepare t, c, target
        sh special + " " + target.source + " " + target.name
        print "\n"
    end
end

task :clean do |target|
    $config.each { |t,cl|
        cl.each { |c,l|
            action_msg 		t, c, target, "CLEAN", :yellow
            sh "rm -rf bin/out/" + t + "/" + c
            sh "rm -rf bin/obj/" + t + "/" + c
            print "\n"
        }
    }
end

