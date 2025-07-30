Config = Config or {}

-- Locale settings
Config.Locale = "sv"  -- change to "fr" or "de" as needed
Config.Locales = {
  en = require("locales.en"),
  fr = require("locales.fr"),
  de = require("locales.de"),
  sv = require("locales.sv"),
}

-- Debugging
Config.debug = false            -- Set to true to visualize zones

-- Notification provider: "ox_lib", "okokNotify" or "rtx_notify"
Config.NotificationProvider = "ox_lib"

-- Optional Raceway Leaderboard Display by Glitchdetector
Config.Leaderboard = {
    enabled = true,
}

--- START / FINISH LINE POLYGON (used for ROSZ detection if you ever need it)
Config.StartLinePoints = {
    vector3(-2761.50, 8084.30, 42.88),
}

--- ADJUSTABLE FINISH‐LINE SPHERE (separate from checkpoints)
Config.FinishLine = {
    boxCorners = {
        vector3( -2762.8942871094, 8085.2436523438, 30.0 ),  -- corner A
        vector3( -2758.9077148438, 8084.9848632813, 30.0 ),  -- corner B
        vector3( -2759.5432128906, 8074.0034179688, 30.5 ),  -- corner C
        vector3( -2763.4086914063, 8074.2348632813, 30.5 ),  -- corner D
    },
    -- you can keep these around to fall back on if you ever need them:
    coords = Config.StartLinePoints[1],
    radius = 15.0
}

--- TRACK CHECKPOINTS (must drive through these in order)
--- LEADERBOARD ACCURACY RELIES ON CHECKPOINT ACCURACY
--- DO NOT CHANGE THESE UNLESS YOU KNOW WHAT YOU ARE DOING ELSE YOU WILL BREAK LEADERBOARD
Config.Checkpoints = {
    Short_Track = {
        vector3(-2554.69, 8193.30, 38.24),    
        vector3(-2719.17, 8335.82, 40.43),    
        vector3(-3097.36, 8308.31, 36.28),
    },
    Drift_Track = {
        vector3(-2519.90, 8237.24, 38.46),
        vector3(-2802.37, 8546.86, 43.96),
        vector3(-2950.20, 8405.94, 36.45),
    },
    Speed_Track = {
        vector3(-2519.90, 8237.24, 38.46),
        vec3(-2378.46, 8679.75, 46.77),
        vec3(-2899.6, 8778.86, 44.94)
    },
    Long_Track = {
        vector3(-2519.90, 8237.24, 38.46),
        vec3(-2312.25, 8541.71, 46.91),
        vec3(-2315.04, 8722.81, 46.77),
        vec3(-2718.7, 8741.76, 44.85)
    },
}

Config.RankingPoints = {
    Short_Track = {
        -- just after race start REQUIRED
        vector3(-2750.33, 8079.47, 42.82),
        -- ① Hairpin entry (just after you leave the straight)
        vector3(-2495.46, 8157.56, 41.97),    
        -- ② Hairpin apex (middle of the U-turn)
        vector3(-2476.55, 8231.21, 41.60),    
        -- ③ Original CP 1 (exit of hairpin)
        vector3(-2554.69, 8193.30, 38.24),    
        -- ④ Original CP 2 (top of the next bend)
        vector3(-2719.17, 8335.82, 40.43),    
        -- ⑤ Original CP 3 (long left sweep)
        vector3(-3097.36, 8308.31, 36.28),
    },
    Drift_Track = {
        -- just after race start REQUIRED
        vector3(-2750.33, 8079.47, 42.82),
        -- ① Hairpin entry (just after you leave the straight)
        vector3(-2495.46, 8157.56, 41.97),    
        -- ② Hairpin apex (middle of the U-turn)
        vector3(-2476.55, 8231.21, 41.60),    
        -- ③ Original CP 1 (exit of hairpin)
        vector3(-2554.69, 8193.30, 38.24),   
        vector3(-2802.37, 8546.86, 43.96),
        vector3(-2950.20, 8405.94, 36.45),
    },
    Speed_Track = {
        -- just after race start REQUIRED
        vector3(-2750.33, 8079.47, 42.82),
        vector3(-2495.46, 8157.56, 41.97),
        vector3(-2476.55, 8231.21, 41.60),
        vector3(-2554.69, 8193.30, 38.24),   
    },
    Long_Track = {
        -- just after race start REQUIRED
        vector3(-2750.33, 8079.47, 42.82),
        vector3(-2495.46, 8157.56, 41.97),    
        vector3(-2476.55, 8231.21, 41.60),
        vector3(-2554.69, 8193.30, 38.24),   
    },
}

--- PIT CREW ZONES
Config.PitCrewZones = {
    -- Zone #1
    {  
      coords  = vector3(-2865.45, 8113.30, 43.74),   
      heading = 180.0,    -- NPCs will face south
      radius  = 6.0  
    },
    -- Zone #2
    {  
      coords  = vector3(-2840.76, 8109.64, 43.55),   
      heading = 180.0,    -- NPCs will face south
      radius  = 6.0  
    },
    -- You can add more zones here
}

-- Pit-crew settings
Config.PitCrewModel       = 'ig_mechanic_01'  -- ped model for all pit crew
Config.PitCrewIdleOffsets = {
    vector3(-2.0,  0.0,  0.0),  -- two idle spots (left/right)
    vector3( 2.0,  0.0,  0.0),
}
Config.PitCrewCrewOffsets = {
    vector3( 0.0, -2.0,  0.0),  -- refuel spot (rear)
    vector3( 0.0,  2.0,  0.0),  -- hood spot (front)
    vector3( 2.0,  0.0,  0.0),  -- jack spot (side)
}

--- OUT COORDS (where to send you when you finish)
Config.outCoords = vector4(-2896.1172, 8077.2363, 44.4940, 183.6707)

--- LOBBY PED
Config.LobbyPed = {
    model  = 's_m_y_valet_01',
    coords = vector4(-2901.4832, 8076.8525, 44.4985, 246.1840),
}

--- TRACK PROPS / BARRIERS
Config.TrackProps = {
    ["Short_Track"] = {
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0l1',
            cords = {
                vector4(-2705.38, 8340.52, 41.36, 338.00),
                vector4(-2700.06, 8335.04, 41.48, 338.00),
                vector4(-2694.68, 8328.46, 41.47, 338.00),
                vector4(-2689.42, 8323.68, 41.47, 338.00),
                vector4(-2683.45, 8320.36, 41.47, 338.00),
                vector4(-2679.92, 8315.29, 41.47, 338.00),
                vector4(-2674.74, 8310.80, 41.47, 338.00),
                vector4(-2905.52, 8346.46, 36.11,  81.12),
            }
        }
    },
    ["Drift_Track"] = {
        -- first barrier set (left side)
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vector4(-2723.00, 8316.50, 40.83,  45),
                vector4(-2719.01, 8320.02, 40.83,  45),
                vector4(-2714.72, 8323.96, 40.84,  45),
                vector4(-2711.34, 8327.73, 40.81,  45),
                vector4(-2707.65, 8330.18, 40.85,  45),
                vector4(-2705.53, 8332.99, 41.49,  45),
                vector4(-2702.49, 8336.08, 40.84,  45),
            }
        },
        -- second barrier set (right side)
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0l1',
            cords = {
                vector4(-2666.57, 8443.34, 40.95, 310),
                vector4(-2663.85, 8440.70, 40.91, 310),
                vector4(-2662.02, 8438.67, 40.93, 310),
                vector4(-2660.13, 8436.43, 40.93, 310),
                vector4(-2658.33, 8434.17, 40.95, 310),
                vector4(-2656.33, 8431.84, 40.96, 310),
                vector4(-2654.59, 8429.54, 40.95, 308),
                vector4(-2652.68, 8427.03, 40.94, 305),
                vector4(-2650.67, 8424.33, 40.94, 303),
                vector4(-2649.04, 8421.65, 40.92, 300),
                vector4(-2647.47, 8419.16, 40.91, 298),
                vector4(-2646.40, 8416.86, 40.90, 299),
            }
        },
        -- third barrier set (right side)
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0l1',
            cords = {
                vector4(-2896.81, 8681.33, 33.38, 317),
                vector4(-2894.57, 8679.58, 33.14, 318),
                vector4(-2892.14, 8677.52, 32.87, 316),
                vector4(-2889.84, 8675.16, 32.61, 319),
                vector4(-2887.58, 8673.02, 32.37, 315),
                vector4(-2885.14, 8670.61, 32.15, 311),
                vector4(-2883.17, 8668.10, 31.97, 307),
                vector4(-2881.19, 8665.45, 31.81, 309),
                vector4(-2879.21, 8662.79, 31.65, 303),
                vector4(-2877.65, 8660.39, 31.52, 300),
                vector4(-2875.98, 8657.30, 31.38, 295),
                vector4(-2874.64, 8654.42, 31.29, 292),
                vector4(-2873.57, 8651.52, 31.31, 287),
                vector4(-2872.55, 8648.54, 31.37, 284),
                vector4(-2871.91, 8645.62, 31.46, 281),
                vector4(-2871.27, 8642.35, 31.60, 277),
                vector4(-2870.78, 8639.22, 31.88, 277),
                vector4(-2870.23, 8636.04, 32.30, 274),
                vector4(-2869.95, 8633.11, 32.72, 273),
                vector4(-2869.88, 8630.21, 33.13, 273),
            }
        },
        -- fourth barrier set (right side)
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vector4(-2878.40, 8363.62, 36.45, 270),
                vector4(-2878.41, 8360.70, 36.44, 268),
                vector4(-2878.48, 8357.19, 36.44, 266),
                vector4(-2878.68, 8353.91, 36.44, 264),
                vector4(-2878.95, 8350.83, 36.44, 263),
                vector4(-2879.32, 8347.71, 36.43, 261),
                vector4(-2879.78, 8344.50, 36.44, 259),
                vector4(-2880.28, 8341.33, 36.44, 258),
                vector4(-2881.02, 8338.01, 36.44, 254),
                vector4(-2881.92, 8334.65, 36.44, 253),
                vector4(-2882.65, 8331.82, 36.44, 252),
            }
        },
    },
    ["Speed_Track"] = {
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vector4(-2723.00, 8316.50, 40.83,  45),
                vector4(-2719.01, 8320.02, 40.83,  45),
                vector4(-2714.72, 8323.96, 40.84,  45),
                vector4(-2711.34, 8327.73, 40.81,  45),
                vector4(-2707.65, 8330.18, 40.85,  45),
                vector4(-2705.53, 8332.99, 41.49,  45),
                vector4(-2702.49, 8336.08, 40.84,  45),
            }
        },
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vec4(-2684.13, 8412.75, 41.47, 55.1),
                vec4(-2681.47, 8417.38, 41.48, 55.59),
                vec4(-2679.14, 8421.51, 41.49, 55.12),
                vec4(-2686.45, 8408.99, 41.46, 55.94),
                vec4(-2676.86, 8425.59, 41.5, 55.36),
                vec4(-2674.49, 8429.77, 41.5, 55.42),
                vec4(-2688.36, 8405.41, 41.5, 55.37),
                vec4(-2691.24, 8401.3, 41.49, 55.34),
                vec4(-2671.25, 8434.95, 41.51, 55.49),
                vec4(-2668.6, 8438.81, 41.52, 55.29)
            }
        },
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0l1',
            cords = {
                vec4(-2372.58, 8527.86, 46.91, 280.6),
                vec4(-2374.43, 8521.94, 46.93, 280.93),
                vec4(-2377.77, 8514.83, 46.95, 280.85),
                vec4(-2380.8, 8508.39, 46.9, 280.02),
                vec4(-2383.31, 8504.24, 46.86, 280.31),
                vec4(-2369.76, 8533.05, 46.9, 280.31)
            }
        },
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
               vec4(-2880.66, 8362.57, 37.06, 270.18),
               vec4(-2880.81, 8358.36, 37.05, 270.55),
               vec4(-2881.52, 8352.8, 37.04, 270.27),
               vec4(-2881.7, 8348.43, 37.04, 270.82),
               vec4(-2881.33, 8343.7, 37.06, 270.12),
               vec4(-2881.77, 8339.11, 37.04, 270.98)
            }
        },
    },
    ["Long_Track"]  = {
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vector4(-2723.00, 8316.50, 40.83,  45),
                vector4(-2719.01, 8320.02, 40.83,  45),
                vector4(-2714.72, 8323.96, 40.84,  45),
                vector4(-2711.34, 8327.73, 40.81,  45),
                vector4(-2707.65, 8330.18, 40.85,  45),
                vector4(-2705.53, 8332.99, 41.49,  45),
                vector4(-2702.49, 8336.08, 40.84,  45),
            }
        },
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vec4(-2684.13, 8412.75, 41.47, 55.1),
                vec4(-2681.47, 8417.38, 41.48, 55.59),
                vec4(-2679.14, 8421.51, 41.49, 55.12),
                vec4(-2686.45, 8408.99, 41.46, 55.94),
                vec4(-2676.86, 8425.59, 41.5, 55.36),
                vec4(-2674.49, 8429.77, 41.5, 55.42),
                vec4(-2688.36, 8405.41, 41.5, 55.37),
                vec4(-2691.24, 8401.3, 41.49, 55.34),
                vec4(-2671.25, 8434.95, 41.51, 55.49),
                vec4(-2668.6, 8438.81, 41.52, 55.29)
            }
        },
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vec4(-2384.95, 8551.71, 46.8, 317.12),
                vec4(-2382.19, 8549.26, 46.79, 317.16),
                vec4(-2379.51, 8546.79, 46.82, 317.18),
                vec4(-2376.02, 8543.71, 46.88, 317.81),
                vec4(-2373.07, 8541.14, 46.92, 317.98),
                vec4(-2369.19, 8538.53, 46.92, 317.76),
                -- Andra sidan bågen
                vec4(-2355.63, 8541.14, 46.93, 379.13),
                vec4(-2352.16, 8542.37, 46.92, 379.65),
                vec4(-2349.39, 8543.37, 46.91, 379.67),
                vec4(-2346.67, 8544.33, 46.9, 379.67),
                vec4(-2343.74, 8545.33, 46.89, 379.67)
            }
        },
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
               vec4(-2880.66, 8362.57, 37.06, 270.18),
               vec4(-2880.81, 8358.36, 37.05, 270.55),
               vec4(-2881.52, 8352.8, 37.04, 270.27),
               vec4(-2881.7, 8348.43, 37.04, 270.82),
               vec4(-2881.33, 8343.7, 37.06, 270.12),
               vec4(-2881.77, 8339.11, 37.04, 270.98)
            }
        },
    },
}

--- VEHICLE OPTIONS
Config.RaceVehicles = {
    { model = "sultanrs" },
    { model = "elegy" },
    { model = "buffalo" },
    { model = "kuruma" },
    { model = "gbcomets2r" },
    { model = "tenf2" },
    { model = "massacro2" },
    { model = "omnis" },
    { model = "issi7" },
    { model = "jester" },
    { model = "italirsx" },

}

--- GRID SPAWN POINTS
Config.GridSpawnPoints = {
    vector4(-2762.9260, 8076.5244, 42.6784, 264.5850),
    vector4(-2764.9563, 8079.9731, 42.6893, 266.6010),
    vector4(-2767.7869, 8083.4434, 42.7054, 266.2213),
}

return Config
