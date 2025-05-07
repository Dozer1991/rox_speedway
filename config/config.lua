return {
    debug = false,  -- or true to visualize zones

    --- Choose your notification provider: "ox_lib" or "okokNotify"
    NotificationProvider = "okokNotify",

    Leaderboard = { -- Optional if you have Raceway Leaderboard Display by Glitchdetector
        enabled = true,              -- set to false to disable
    },
    
    StartLinePoints = { -- PolyZone box
        vector3(-2762.60, 8076.12, 42.87),
        vector3(-2762.03, 8083.86, 42.87),
        vector3(-2819.34, 8089.74, 43.27),
        vector3(-2817.58, 8082.80, 43.24),
    },

    -- TRACK CHECKPOINTS (must drive through these in order)
    Checkpoints = {
        Short_Track = {
            vector3(-2519.90, 8237.24, 38.46),
            vector3(-2719.17, 8335.82, 40.43),
            vector3(-3102.41, 8305.79, 35.85),
        },
        Drift_Track = {
            vector3(-2519.90, 8237.24, 38.46),
            vector3(-2802.37, 8546.86, 43.96),
            vector3(-2950.20, 8405.94, 36.45),
        },
        Speed_Track = {
            vector3(-2519.90, 8237.24, 38.46),
          vector3(350.0, 250.0, 102.0),
          vector3(400.0, 300.0, 102.0),
        },
        Long_Track = {
            vector3(-2519.90, 8237.24, 38.46),
          vector3(150.0, 150.0, 102.0),
          vector3(200.0, 200.0, 102.0),
          vector3(250.0, 250.0, 102.0),
        },
    },

    outCoords = vec4(-2896.1172, 8077.2363, 44.4940, 183.6707),

    LobbyPed = {
        model = 's_m_y_valet_01',
        coords = vector4(-2901.4832, 8076.8525, 44.4985, 246.1840)
    },

    TrackProps = {
        ["Short_Track"] = {
            {
                prop = 'sum_prop_ac_tyre_wall_lit_0l1', 
                cords = {
                    vec4(-2705.38, 8340.52, 41.36, 338.00),
                    vec4(-2700.06, 8335.04, 41.48, 338.00),
                    vec4(-2694.68, 8328.46, 41.47, 338.00),
                    vec4(-2689.42, 8323.68, 41.47, 338.00),
                    vec4(-2683.45, 8320.36, 41.47, 338.00),
                    vec4(-2679.92, 8315.29, 41.47, 338.00),
                    vec4(-2674.74, 8310.80, 41.47, 338.00),
                    vec4(-2905.52, 8346.46, 36.11, 81.12)
                }
            }
        },
        ["Drift_Track"] = {
            -- first barrier set (left side)
            {
                prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
                cords = {
                    vector4(-2723.00, 8316.50, 40.83, 45),
                    vector4(-2719.01, 8320.02, 40.83, 45),
                    vector4(-2714.72, 8323.96, 40.84, 45),
                    vector4(-2711.34, 8327.73, 40.81, 45),
                    vector4(-2707.65, 8330.18, 40.85, 45),
                    vector4(-2705.53, 8332.99, 41.49, 45),
                    vector4(-2702.49, 8336.08, 40.84, 45)
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
                    vector4(-2646.40, 8416.86, 40.90, 299)
                }
            },
            -- Third barrier set (right side)
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
                    vector4(-2869.88, 8630.21, 33.13, 273)
                }
            },
            -- Fourth barrier set (right side)
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
                    vector4(-2882.65, 8331.82, 36.44, 252)
                }
            },
        },
        ["Speed_Track"] = {},
        ["Long_Track"] = {}      
    },

    RaceVehicles = {
        { label = "Sultan RS", model = "sultanrs" },
        { label = "Elegy RH8", model = "elegy" },
        { label = "Buffalo", model = "buffalo" },
        { label = "Kuruma", model = "kuruma" },
        { label = "2023WRCI20", model = "2023WRCI20" },
        { label = "WRC2006", model = "WRC2006" },
        { label = "YarisWRC", model = "YarisWRC" }
    },

    GridSpawnPoints = {
        vec4(-2762.9260, 8076.5244, 42.6784, 264.5850),
        vec4(-2764.9563, 8079.9731, 42.6893, 266.6010),
        vec4(-2767.7869, 8083.4434, 42.7054, 266.2213),
    },

}