{application,muontrap,
             [{optional_applications,[]},
              {applications,[kernel,stdlib,elixir,logger]},
              {description,"Keep your ports contained"},
              {modules,['Elixir.MuonTrap','Elixir.MuonTrap.Cgroups',
                        'Elixir.MuonTrap.Daemon','Elixir.MuonTrap.Options',
                        'Elixir.MuonTrap.Port']},
              {registered,[]},
              {vsn,"1.5.0"}]}.
