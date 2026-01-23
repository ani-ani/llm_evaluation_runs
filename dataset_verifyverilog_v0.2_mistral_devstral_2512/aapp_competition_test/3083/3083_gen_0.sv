module playlist_solver (
  input clk,
  input rst_n,
  input start,
  input [6:0] n,
  input [3:0] num_edges_1, num_edges_2, num_edges_3, num_edges_4, num_edges_5, num_edges_6, num_edges_7, num_edges_8, num_edges_9, num_edges_10,
  input [3:0] num_edges_11, num_edges_12, num_edges_13, num_edges_14, num_edges_15, num_edges_16, num_edges_17, num_edges_18, num_edges_19, num_edges_20,
  input [3:0] num_edges_21, num_edges_22, num_edges_23, num_edges_24, num_edges_25, num_edges_26, num_edges_27, num_edges_28, num_edges_29, num_edges_30,
  input [3:0] num_edges_31, num_edges_32, num_edges_33, num_edges_34, num_edges_35, num_edges_36, num_edges_37, num_edges_38, num_edges_39, num_edges_40,
  input [3:0] num_edges_41, num_edges_42, num_edges_43, num_edges_44, num_edges_45, num_edges_46, num_edges_47, num_edges_48, num_edges_49, num_edges_50,
  input [3:0] num_edges_51, num_edges_52, num_edges_53, num_edges_54, num_edges_55, num_edges_56, num_edges_57, num_edges_58, num_edges_59, num_edges_60,
  input [3:0] num_edges_61, num_edges_62, num_edges_63, num_edges_64, num_edges_65, num_edges_66, num_edges_67, num_edges_68, num_edges_69, num_edges_70,
  input [3:0] num_edges_71, num_edges_72, num_edges_73, num_edges_74, num_edges_75, num_edges_76, num_edges_77, num_edges_78, num_edges_79, num_edges_80,
  input [3:0] num_edges_81, num_edges_82, num_edges_83, num_edges_84, num_edges_85, num_edges_86, num_edges_87, num_edges_88, num_edges_89, num_edges_90,
  input [3:0] num_edges_91, num_edges_92, num_edges_93, num_edges_94, num_edges_95, num_edges_96, num_edges_97, num_edges_98, num_edges_99, num_edges_100,
  input [6:0] edge_1_1, edge_1_2, edge_1_3, edge_1_4, edge_1_5, edge_1_6, edge_1_7, edge_1_8, edge_1_9, edge_1_10,
  input [6:0] edge_1_11, edge_1_12, edge_1_13, edge_1_14, edge_1_15, edge_1_16, edge_1_17, edge_1_18, edge_1_19, edge_1_20,
  input [6:0] edge_1_21, edge_1_22, edge_1_23, edge_1_24, edge_1_25, edge_1_26, edge_1_27, edge_1_28, edge_1_29, edge_1_30,
  input [6:0] edge_1_31, edge_1_32, edge_1_33, edge_1_34, edge_1_35, edge_1_36, edge_1_37, edge_1_38, edge_1_39, edge_1_40,
  input [6:0] edge_2_1, edge_2_2, edge_2_3, edge_2_4, edge_2_5, edge_2_6, edge_2_7, edge_2_8, edge_2_9, edge_2_10,
  input [6:0] edge_2_11, edge_2_12, edge_2_13, edge_2_14, edge_2_15, edge_2_16, edge_2_17, edge_2_18, edge_2_19, edge_2_20,
  input [6:0] edge_2_21, edge_2_22, edge_2_23, edge_2_24, edge_2_25, edge_2_26, edge_2_27, edge_2_28, edge_2_29, edge_2_30,
  input [6:0] edge_2_31, edge_2_32, edge_2_33, edge_2_34, edge_2_35, edge_2_36, edge_2_37, edge_2_38, edge_2_39, edge_2_40,
  input [6:0] edge_3_1, edge_3_2, edge_3_3, edge_3_4, edge_3_5, edge_3_6, edge_3_7, edge_3_8, edge_3_9, edge_3_10,
  input [6:0] edge_3_11, edge_3_12, edge_3_13, edge_3_14, edge_3_15, edge_3_16, edge_3_17, edge_3_18, edge_3_19, edge_3_20,
  input [6:0] edge_3_21, edge_3_22, edge_3_23, edge_3_24, edge_3_25, edge_3_26, edge_3_27, edge_3_28, edge_3_29, edge_3_30,
  input [6:0] edge_3_31, edge_3_32, edge_3_33, edge_3_34, edge_3_35, edge_3_36, edge_3_37, edge_3_38, edge_3_39, edge_3_40,
  input [6:0] edge_4_1, edge_4_2, edge_4_3, edge_4_4, edge_4_5, edge_4_6, edge_4_7, edge_4_8, edge_4_9, edge_4_10,
  input [6:0] edge_4_11, edge_4_12, edge_4_13, edge_4_14, edge_4_15, edge_4_16, edge_4_17, edge_4_18, edge_4_19, edge_4_20,
  input [6:0] edge_4_21, edge_4_22, edge_4_23, edge_4_24, edge_4_25, edge_4_26, edge_4_27, edge_4_28, edge_4_29, edge_4_30,
  input [6:0] edge_4_31, edge_4_32, edge_4_33, edge_4_34, edge_4_35, edge_4_36, edge_4_37, edge_4_38, edge_4_39, edge_4_40,
  input [6:0] edge_5_1, edge_5_2, edge_5_3, edge_5_4, edge_5_5, edge_5_6, edge_5_7, edge_5_8, edge_5_9, edge_5_10,
  input [6:0] edge_5_11, edge_5_12, edge_5_13, edge_5_14, edge_5_15, edge_5_16, edge_5_17, edge_5_18, edge_5_19, edge_5_20,
  input [6:0] edge_5_21, edge_5_22, edge_5_23, edge_5_24, edge_5_25, edge_5_26, edge_5_27, edge_5_28, edge_5_29, edge_5_30,
  input [6:0] edge_5_31, edge_5_32, edge_5_33, edge_5_34, edge_5_35, edge_5_36, edge_5_37, edge_5_38, edge_5_39, edge_5_40,
  input [6:0] edge_6_1, edge_6_2, edge_6_3, edge_6_4, edge_6_5, edge_6_6, edge_6_7, edge_6_8, edge_6_9, edge_6_10,
  input [6:0] edge_6_11, edge_6_12, edge_6_13, edge_6_14, edge_6_15, edge_6_16, edge_6_17, edge_6_18, edge_6_19, edge_6_20,
  input [6:0] edge_6_21, edge_6_22, edge_6_23, edge_6_24, edge_6_25, edge_6_26, edge_6_27, edge_6_28, edge_6_29, edge_6_30,
  input [6:0] edge_6_31, edge_6_32, edge_6_33, edge_6_34, edge_6_35, edge_6_36, edge_6_37, edge_6_38, edge_6_39, edge_6_40,
  input [6:0] edge_7_1, edge_7_2, edge_7_3, edge_7_4, edge_7_5, edge_7_6, edge_7_7, edge_7_8, edge_7_9, edge_7_10,
  input [6:0] edge_7_11, edge_7_12, edge_7_13, edge_7_14, edge_7_15, edge_7_16, edge_7_17, edge_7_18, edge_7_19, edge_7_20,
  input [6:0] edge_7_21, edge_7_22, edge_7_23, edge_7_24, edge_7_25, edge_7_26, edge_7_27, edge_7_28, edge_7_29, edge_7_30,
  input [6:0] edge_7_31, edge_7_32, edge_7_33, edge_7_34, edge_7_35, edge_7_36, edge_7_37, edge_7_38, edge_7_39, edge_7_40,
  input [6:0] edge_8_1, edge_8_2, edge_8_3, edge_8_4, edge_8_5, edge_8_6, edge_8_7, edge_8_8, edge_8_9, edge_8_10,
  input [6:0] edge_8_11, edge_8_12, edge_8_13, edge_8_14, edge_8_15, edge_8_16, edge_8_17, edge_8_18, edge_8_19, edge_8_20,
  input [6:0] edge_8_21, edge_8_22, edge_8_23, edge_8_24, edge_8_25, edge_8_26, edge_8_27, edge_8_28, edge_8_29, edge_8_30,
  input [6:0] edge_8_31, edge_8_32, edge_8_33, edge_8_34, edge_8_35, edge_8_36, edge_8_37, edge_8_38, edge_8_39, edge_8_40,
  input [6:0] edge_9_1, edge_9_2, edge_9_3, edge_9_4, edge_9_5, edge_9_6, edge_9_7, edge_9_8, edge_9_9, edge_9_10,
  input [6:0] edge_9_11, edge_9_12, edge_9_13, edge_9_14, edge_9_15, edge_9_16, edge_9_17, edge_9_18, edge_9_19, edge_9_20,
  input [6:0] edge_9_21, edge_9_22, edge_9_23, edge_9_24, edge_9_25, edge_9_26, edge_9_27, edge_9_28, edge_9_29, edge_9_30,
  input [6:0] edge_9_31, edge_9_32, edge_9_33, edge_9_34, edge_9_35, edge_9_36, edge_9_37, edge_9_38, edge_9_39, edge_9_40,
  input [6:0] edge_10_1, edge_10_2, edge_10_3, edge_10_4, edge_10_5, edge_10_6, edge_10_7, edge_10_8, edge_10_9, edge_10_10,
  input [6:0] edge_10_11, edge_10_12, edge_10_13, edge_10_14, edge_10_15, edge_10_16, edge_10_17, edge_10_18, edge_10_19, edge_10_20,
  input [6:0] edge_10_21, edge_10_22, edge_10_23, edge_10_24, edge_10_25, edge_10_26, edge_10_27, edge_10_28, edge_10_29, edge_10_30,
  input [6:0] edge_10_31, edge_10_32, edge_10_33, edge_10_34, edge_10_35, edge_10_36, edge_10_37, edge_10_38, edge_10_39, edge_10_40,
  input [6:0] edge_11_1, edge_11_2, edge_11_3, edge_11_4, edge_11_5, edge_11_6, edge_11_7, edge_11_8, edge_11_9, edge_11_10,
  input [6:0] edge_11_11, edge_11_12, edge_11_13, edge_11_14, edge_11_15, edge_11_16, edge_11_17, edge_11_18, edge_11_19, edge_11_20,
  input [6:0] edge_11_21, edge_11_22, edge_11_23, edge_11_24, edge_11_25, edge_11_26, edge_11_27, edge_11_28, edge_11_29, edge_11_30,
  input [6:0] edge_11_31, edge_11_32, edge_11_33, edge_11_34, edge_11_35, edge_11_36, edge_11_37, edge_11_38, edge_11_39, edge_11_40,
  input [6:0] edge_12_1, edge_12_2, edge_12_3, edge_12_4, edge_12_5, edge_12_6, edge_12_7, edge_12_8, edge_12_9, edge_12_10,
  input [6:0] edge_12_11, edge_12_12, edge_12_13, edge_12_14, edge_12_15, edge_12_16, edge_12_17, edge_12_18, edge_12_19, edge_12_20,
  input [6:0] edge_12_21, edge_12_22, edge_12_23, edge_12_24, edge_12_25, edge_12_26, edge_12_27, edge_12_28, edge_12_29, edge_12_30,
  input [6:0] edge_12_31, edge_12_32, edge_12_33, edge_12_34, edge_12_35, edge_12_36, edge_12_37, edge_12_38, edge_12_39, edge_12_40,
  input [6:0] edge_13_1, edge_13_2, edge_13_3, edge_13_4, edge_13_5, edge_13_6, edge_13_7, edge_13_8, edge_13_9, edge_13_10,
  input [6:0] edge_13_11, edge_13_12, edge_13_13, edge_13_14, edge_13_15, edge_13_16, edge_13_17, edge_13_18, edge_13_19, edge_13_20,
  input [6:0] edge_13_21, edge_13_22, edge_13_23, edge_13_24, edge_13_25, edge_13_26, edge_13_27, edge_13_28, edge_13_29, edge_13_30,
  input [6:0] edge_13_31, edge_13_32, edge_13_33, edge_13_34, edge_13_35, edge_13_36, edge_13_37, edge_13_38, edge_13_39, edge_13_40,
  input [6:0] edge_14_1, edge_14_2, edge_14_3, edge_14_4, edge_14_5, edge_14_6, edge_14_7, edge_14_8, edge_14_9, edge_14_10,
  input [6:0] edge_14_11, edge_14_12, edge_14_13, edge_14_14, edge_14_15, edge_14_16, edge_14_17, edge_14_18, edge_14_19, edge_14_20,
  input [6:0] edge_14_21, edge_14_22, edge_14_23, edge_14_24, edge_14_25, edge_14_26, edge_14_27, edge_14_28, edge_14_29, edge_14_30,
  input [6:0] edge_14_31, edge_14_32, edge_14_33, edge_14_34, edge_14_35, edge_14_36, edge_14_37, edge_14_38, edge_14_39, edge_14_40,
  input [6:0] edge_15_1, edge_15_2, edge_15_3, edge_15_4, edge_15_5, edge_15_6, edge_15_7, edge_15_8, edge_15_9, edge_15_10,
  input [6:0] edge_15_11, edge_15_12, edge_15_13, edge_15_14, edge_15_15, edge_15_16, edge_15_17, edge_15_18, edge_15_19, edge_15_20,
  input [6:0] edge_15_21, edge_15_22, edge_15_23, edge_15_24, edge_15_25, edge_15_26, edge_15_27, edge_15_28, edge_15_29, edge_15_30,
  input [6:0] edge_15_31, edge_15_32, edge_15_33, edge_15_34, edge_15_35, edge_15_36, edge_15_37, edge_15_38, edge_15_39, edge_15_40,
  input [6:0] edge_16_1, edge_16_2, edge_16_3, edge_16_4, edge_16_5, edge_16_6, edge_16_7, edge_16_8, edge_16_9, edge_16_10,
  input [6:0] edge_16_11, edge_16_12, edge_16_13, edge_16_14, edge_16_15, edge_16_16, edge_16_17, edge_16_18, edge_16_19, edge_16_20,
  input [6:0] edge_16_21, edge_16_22, edge_16_23, edge_16_24, edge_16_25, edge_16_26, edge_16_27, edge_16_28, edge_16_29, edge_16_30,
  input [6:0] edge_16_31, edge_16_32, edge_16_33, edge_16_34, edge_16_35, edge_16_36, edge_16_37, edge_16_38, edge_16_39, edge_16_40,
  input [6:0] edge_17_1, edge_17_2, edge_17_3, edge_17_4, edge_17_5, edge_17_6, edge_17_7, edge_17_8, edge_17_9, edge_17_10,
  input [6:0] edge_17_11, edge_17_12, edge_17_13, edge_17_14, edge_17_15, edge_17_16, edge_17_17, edge_17_18, edge_17_19, edge_17_20,
  input [6:0] edge_17_21, edge_17_22, edge_17_23, edge_17_24, edge_17_25, edge_17_26, edge_17_27, edge_17_28, edge_17_29, edge_17_30,
  input [6:0] edge_17_31, edge_17_32, edge_17_33, edge_17_34, edge_17_35, edge_17_36, edge_17_37, edge_17_38, edge_17_39, edge_17_40,
  input [6:0] edge_18_1, edge_18_2, edge_18_3, edge_18_4, edge_18_5, edge_18_6, edge_18_7, edge_18_8, edge_18_9, edge_18_10,
  input [6:0] edge_18_11, edge_18_12, edge_18_13, edge_18_14, edge_18_15, edge_18_16, edge_18_17, edge_18_18, edge_18_19, edge_18_20,
  input [6:0] edge_18_21, edge_18_22, edge_18_23, edge_18_24, edge_18_25, edge_18_26, edge_18_27, edge_18_28, edge_18_29, edge_18_30,
  input [6:0] edge_18_31, edge_18_32, edge_18_33, edge_18_34, edge_18_35, edge_18_36, edge_18_37, edge_18_38, edge_18_39, edge_18_40,
  input [6:0] edge_19_1, edge_19_2, edge_19_3, edge_19_4, edge_19_5, edge_19_6, edge_19_7, edge_19_8, edge_19_9, edge_19_10,
  input [6:0] edge_19_11, edge_19_12, edge_19_13, edge_19_14, edge_19_15, edge_19_16, edge_19_17, edge_19_18, edge_19_19, edge_19_20,
  input [6:0] edge_19_21, edge_19_22, edge_19_23, edge_19_24, edge_19_25, edge_19_26, edge_19_27, edge_19_28, edge_19_29, edge_19_30,
  input [6:0] edge_19_31, edge_19_32, edge_19_33, edge_19_34, edge_19_35, edge_19_36, edge_19_37, edge_19_38, edge_19_39, edge_19_40,
  input [6:0] edge_20_1, edge_20_2, edge_20_3, edge_20_4, edge_20_5, edge_20_6, edge_20_7, edge_20_8, edge_20_9, edge_20_10,
  input [6:0] edge_20_11, edge_20_12, edge_20_13, edge_20_14, edge_20_15, edge_20_16, edge_20_17, edge_20_18, edge_20_19, edge_20_20,
  input [6:0] edge_20_21, edge_20_22, edge_20_23, edge_20_24, edge_20_25, edge_20_26, edge_20_27, edge_20_28, edge_20_29, edge_20_30,
  input [6:0] edge_20_31, edge_20_32, edge_20_33, edge_20_34, edge_20_35, edge_20_36, edge_20_37, edge_20_38, edge_20_39, edge_20_40,
  input [6:0] edge_21_1, edge_21_2, edge_21_3, edge_21_4, edge_21_5, edge_21_6, edge_21_7, edge_21_8, edge_21_9, edge_21_10,
  input [6:0] edge_21_11, edge_21_12, edge_21_13, edge_21_14, edge_21_15, edge_21_16, edge_21_17, edge_21_18, edge_21_19, edge_21_20,
  input [6:0] edge_21_21, edge_21_22, edge_21_23, edge_21_24, edge_21_25, edge_21_26, edge_21_27, edge_21_28, edge_21_29, edge_21_30,
  input [6:0] edge_21_31, edge_21_32, edge_21_33, edge_21_34, edge_21_35, edge_21_36, edge_21_37, edge_21_38, edge_21_39, edge_21_40,
  input [6:0] edge_22_1, edge_22_2, edge_22_3, edge_22_4, edge_22_5, edge_22_6, edge_22_7, edge_22_8, edge_22_9, edge_22_10,
  input [6:0] edge_22_11, edge_22_12, edge_22_13, edge_22_14, edge_22_15, edge_22_16, edge_22_17, edge_22_18, edge_22_19, edge_22_20,
  input [6:0] edge_22_21, edge_22_22, edge_22_23, edge_22_24, edge_22_25, edge_22_26, edge_22_27, edge_22_28, edge_22_29, edge_22_30,
  input [6:0] edge_22_31, edge_22_32, edge_22_33, edge_22_34, edge_22_35, edge_22_36, edge_22_37, edge_22_38, edge_22_39, edge_22_40,
  input [6:0] edge_23_1, edge_23_2, edge_23_3, edge_23_4, edge_23_5, edge_23_6, edge_23_7, edge_23_8, edge_23_9, edge_23_10,
  input [6:0] edge_23_11, edge_23_12, edge_23_13, edge_23_14, edge_23_15, edge_23_16, edge_23_17, edge_23_18, edge_23_19, edge_23_20,
  input [6:0] edge_23_21, edge_23_22, edge_23_23, edge_23_24, edge_23_25, edge_23_26, edge_23_27, edge_23_28, edge_23_29, edge_23_30,
  input [6:0] edge_23_31, edge_23_32, edge_23_33, edge_23_34, edge_23_35, edge_23_36, edge_23_37, edge_23_38, edge_23_39, edge_23_40,
  input [6:0] edge_24_1, edge_24_2, edge_24_3, edge_24_4, edge_24_5, edge_24_6, edge_24_7, edge_24_8, edge_24_9, edge_24_10,
  input [6:0] edge_24_11, edge_24_12, edge_24_13, edge_24_14, edge_24_15, edge_24_16, edge_24_17, edge_24_18, edge_24_19, edge_24_20,
  input [6:0] edge_24_21, edge_24_22, edge_24_23, edge_24_24, edge_24_25, edge_24_26, edge_24_27, edge_24_28, edge_24_29, edge_24_30,
  input [6:0] edge_24_31, edge_24_32, edge_24_33, edge_24_34, edge_24_35, edge_24_36, edge_24_37, edge_24_38, edge_24_39, edge_24_40,
  input [6:0] edge_25_1, edge_25_2, edge_25_3, edge_25_4, edge_25_5, edge_25_6, edge_25_7, edge_25_8, edge_25_9, edge_25_10,
  input [6:0] edge_25_11, edge_25_12, edge_25_13, edge_25_14, edge_25_15, edge_25_16, edge_25_17, edge_25_18, edge_25_19, edge_25_20,
  input [6:0] edge_25_21, edge_25_22, edge_25_23, edge_25_24, edge_25_25, edge_25_26, edge_25_27, edge_25_28, edge_25_29, edge_25_30,
  input [6:0] edge_25_31, edge_25_32, edge_25_33, edge_25_34, edge_25_35, edge_25_36, edge_25_37, edge_25_38, edge_25_39, edge_25_40,
  input [6:0] edge_26_1, edge_26_2, edge_26_3, edge_26_4, edge_26_5, edge_26_6, edge_26_7, edge_26_8, edge_26_9, edge_26_10,
  input [6:0] edge_26_11, edge_26_12, edge_26_13, edge_26_14, edge_26_15, edge_26_16, edge_26_17, edge_26_18, edge_26_19, edge_26_20,
  input [6:0] edge_26_21, edge_26_22, edge_26_23, edge_26_24, edge_26_25, edge_26_26, edge_26_27, edge_26_28, edge_26_29, edge_26_30,
  input [6:0] edge_26_31, edge_26_32, edge_26_33, edge_26_34, edge_26_35, edge_26_36, edge_26_37, edge_26_38, edge_26_39, edge_26_40,
  input [6:0] edge_27_1, edge_27_2, edge_27_3, edge_27_4, edge_27_5, edge_27_6, edge_27_7, edge_27_8, edge_27_9, edge_27_10,
  input [6:0] edge_27_11, edge_27_12, edge_27_13, edge_27_14, edge_27_15, edge_27_16, edge_27_17, edge_27_18, edge_27_19, edge_27_20,
  input [6:0] edge_27_21, edge_27_22, edge_27_23, edge_27_24, edge_27_25, edge_27_26, edge_27_27, edge_27_28, edge_27_29, edge_27_30,
  input [6:0] edge_27_31, edge_27_32, edge_27_33, edge_27_34, edge_27_35, edge_27_36, edge_27_37, edge_27_38, edge_27_39, edge_27_40,
  input [6:0] edge_28_1, edge_28_2, edge_28_3, edge_28_4, edge_28_5, edge_28_6, edge_28_7, edge_28_8, edge_28_9, edge_28_10,
  input [6:0] edge_28_11, edge_28_12, edge_28_13, edge_28_14, edge_28_15, edge_28_16, edge_28_17, edge_28_18, edge_28_19, edge_28_20,
  input [6:0] edge_28_21, edge_28_22, edge_28_23, edge_28_24, edge_28_25, edge_28_26, edge_28_27, edge_28_28, edge_28_29, edge_28_30,
  input [6:0] edge_28_31, edge_28_32, edge_28_33, edge_28_34, edge_28_35, edge_28_36, edge_28_37, edge_28_38, edge_28_39, edge_28_40,
  input [6:0] edge_29_1, edge_29_2, edge_29_3, edge_29_4, edge_29_5, edge_29_6, edge_29_7, edge_29_8, edge_29_9, edge_29_10,
  input [6:0] edge_29_11, edge_29_12, edge_29_13, edge_29_14, edge_29_15, edge_29_16, edge_29_17, edge_29_18, edge_29_19, edge_29_20,
  input [6:0] edge_29_21, edge_29_22, edge_29_23, edge_29_24, edge_29_25, edge_29_26, edge_29_27, edge_29_28, edge_29_29, edge_29_30,
  input [6:0] edge_29_31, edge_29_32, edge_29_33, edge_29_34, edge_29_35, edge_29_36, edge_29_37, edge_29_38, edge_29_39, edge_29_40,
  input [6:0] edge_30_1, edge_30_2, edge_30_3, edge_30_4, edge_30_5, edge_30_6, edge_30_7, edge_30_8, edge_30_9, edge_30_10,
  input [6:0] edge_30_11, edge_30_12, edge_30_13, edge_30_14, edge_30_15, edge_30_16, edge_30_17, edge_30_18, edge_30_19, edge_30_20,
  input [6:0] edge_30_21, edge_30_22, edge_30_23, edge_30_24, edge_30_25, edge_30_26, edge_30_27, edge_30_28, edge_30_29, edge_30_30,
  input [6:0] edge_30_31, edge_30_32, edge_30_33, edge_30_34, edge_30_35, edge_30_36, edge_30_37, edge_30_38, edge_30_39, edge_30_40,
  input [6:0] edge_31_1, edge_31_2, edge_31_3, edge_31_4, edge_31_5, edge_31_6, edge_31_7, edge_31_8, edge_31_9, edge_31_10,
  input [6:0] edge_31_11, edge_31_12, edge_31_13, edge_31_14, edge_31_15, edge_31_16, edge_31_17, edge_31_18, edge_31_19, edge_31_20,
  input [6:0] edge_31_21, edge_31_22, edge_31_23, edge_31_24, edge_31_25, edge_31_26, edge_31_27, edge_31_28, edge_31_29, edge_31_30,
  input [6:0] edge_31_31, edge_31_32, edge_31_33, edge_31_34, edge_31_35, edge_31_36, edge_31_37, edge_31_38, edge_31_39, edge_31_40,
  input [6:0] edge_32_1, edge_32_2, edge_32_3, edge_32_4, edge_32_5, edge_32_6, edge_32_7, edge_32_8, edge_32_9, edge_32_10,
  input [6:0] edge_32_11, edge_32_12, edge_32_13, edge_32_14, edge_32_15, edge_32_16, edge_32_17, edge_32_18, edge_32_19, edge_32_20,
  input [6:0] edge_32_21, edge_32_22, edge_32_23, edge_32_24, edge_32_25, edge_32_26, edge_32_27, edge_32_28, edge_32_29, edge_32_30,
  input [6:0] edge_32_31, edge_32_32, edge_32_33, edge_32_34, edge_32_35, edge_32_36, edge_32_37, edge_32_38, edge_32_39, edge_32_40,
  input [6:0] edge_33_1, edge_33_2, edge_33_3, edge_33_4, edge_33_5, edge_33_6, edge_33_7, edge_33_8, edge_33_9, edge_33_10,
  input [6:0] edge_33_11, edge_33_12, edge_33_13, edge_33_14, edge_33_15, edge_33_16, edge_33_17, edge_33_18, edge_33_19, edge_33_20,
  input [6:0] edge_33_21, edge_33_22, edge_33_23, edge_33_24, edge_33_25, edge_33_26, edge_33_27, edge_33_28, edge_33_29, edge_33_30,
  input [6:0] edge_33_31, edge_33_32, edge_33_33, edge_33_34, edge_33_35, edge_33_36, edge_33_37, edge_33_38, edge_33_39, edge_33_40,
  input [6:0] edge_34_1, edge_34_2, edge_34_3, edge_34_4, edge_34_5, edge_34_6, edge_34_7, edge_34_8, edge_34_9, edge_34_10,
  input [6:0] edge_34_11, edge_34_12, edge_34_13, edge_34_14, edge_34_15, edge_34_16, edge_34_17, edge_34_18, edge_34_19, edge_34_20,
  input [6:0] edge_34_21, edge_34_22, edge_34_23, edge_34_24, edge_34_25, edge_34_26, edge_34_27, edge_34_28, edge_34_29, edge_34_30,
  input [6:0] edge_34_31, edge_34_32, edge_34_33, edge_34_34, edge_34_35, edge_34_36, edge_34_37, edge_34_38, edge_34_39, edge_34_40,
  input [6:0] edge_35_1, edge_35_2, edge_35_3, edge_35_4, edge_35_5, edge_35_6, edge_35_7, edge_35_8, edge_35_9, edge_35_10,
  input [6:0] edge_35_11, edge_35_12, edge_35_13, edge_35_14, edge_35_15, edge_35_16, edge_35_17, edge_35_18, edge_35_19, edge_35_20,
  input [6:0] edge_35_21, edge_35_22, edge_35_23, edge_35_24, edge_35_25, edge_35_26, edge_35_27, edge_35_28, edge_35_29, edge_35_30,
  input [6:0] edge_35_31, edge_35_32, edge_35_33, edge_35_34, edge_35_35, edge_35_36, edge_35_37, edge_35_38, edge_35_39, edge_35_40,
  input [6:0] edge_36_1, edge_36_2, edge_36_3, edge_36_4, edge_36_5, edge_36_6, edge_36_7, edge_36_8, edge_36_9, edge_36_10,
  input [6:0] edge_36_11, edge_36_12, edge_36_13, edge_36_14, edge_36_15, edge_36_16, edge_36_17, edge_36_18, edge_36_19, edge_36_20,
  input [6:0] edge_36_21, edge_36_22, edge_36_23, edge_36_24, edge_36_25, edge_36_26, edge_36_27, edge_36_28, edge_36_29, edge_36_30,
  input [6:0] edge_36_31, edge_36_32, edge_36_33, edge_36_34, edge_36_35, edge_36_36, edge_36_37, edge_36_38, edge_36_39, edge_36_40,
  input [6:0] edge_37_1, edge_37_2, edge_37_3, edge_37_4, edge_37_5, edge_37_6, edge_37_7, edge_37_8, edge_37_9, edge_37_10,
  input [6:0] edge_37_11, edge_37_12, edge_37_13, edge_37_14, edge_37_15, edge_37_16, edge_37_17, edge_37_18, edge_37_19, edge_37_20,
  input [6:0] edge_37_21, edge_37_22, edge_37_23, edge_37_24, edge_37_25, edge_37_26, edge_37_27, edge_37_28, edge_37_29, edge_37_30,
  input [6:0] edge_37_31, edge_37_32, edge_37_33, edge_37_34, edge_37_35, edge_37_36, edge_37_37, edge_37_38, edge_37_39, edge_37_40,
  input [6:0] edge_38_1, edge_38_2, edge_38_3, edge_38_4, edge_38_5, edge_38_6, edge_38_7, edge_38_8, edge_38_9, edge_38_10,
  input [6:0] edge_38_11, edge_38_12, edge_38_13, edge_38_14, edge_38_15, edge_38_16, edge_38_17, edge_38_18, edge_38_19, edge_38_20,
  input [6:0] edge_38_21, edge_38_22, edge_38_23, edge_38_24, edge_38_25, edge_38_26, edge_38_27, edge_38_28, edge_38_29, edge_38_30,
  input [6:0] edge_38_31, edge_38_32, edge_38_33, edge_38_34, edge_38_35, edge_38_36, edge_38_37, edge_38_38, edge_38_39, edge_38_40,
  input [6:0] edge_39_1, edge_39_2, edge_39_3, edge_39_4, edge_39_5, edge_39_6, edge_39_7, edge_39_8, edge_39_9, edge_39_10,
  input [6:0] edge_39_11, edge_39_12, edge_39_13, edge_39_14, edge_39_15, edge_39_16, edge_39_17, edge_39_18, edge_39_19, edge_39_20,
  input [6:0] edge_39_21, edge_39_22, edge_39_23, edge_39_24, edge_39_25, edge_39_26, edge_39_27, edge_39_28, edge_39_29, edge_39_30,
  input [6:0] edge_39_31, edge_39_32, edge_39_33, edge_39_34, edge_39_35, edge_39_36, edge_39_37, edge_39_38, edge_39_39, edge_39_40,
  input [6:0] edge_40_1, edge_40_2, edge_40_3, edge_40_4, edge_40_5, edge_40_6, edge_40_7, edge_40_8, edge_40_9, edge_40_10,
  input [6:0] edge_40_11, edge_40_12, edge_40_13, edge_40_14, edge_40_15, edge_40_16, edge_40_17, edge_40_18, edge_40_19, edge_40_20,
  input [6:0] edge_40_21, edge_40_22, edge_40_23, edge_40_24, edge_40_25, edge_40_26, edge_40_27, edge_40_28, edge_40_29, edge_40_30,
  input [6:0] edge_40_31, edge_40_32, edge_40_33, edge_40_34, edge_40_35, edge_40_36, edge_40_37, edge_40_38, edge_40_39, edge_40_40,
  input [6:0] edge_41_1, edge_41_2, edge_41_3, edge_41_4, edge_41_5, edge_41_6, edge_41_7, edge_41_8, edge_41_9, edge_41_10,
  input [6:0] edge_41_11, edge_41_12, edge_41_13, edge_41_14, edge_41_15, edge_41_16, edge_41_17, edge_41_18, edge_41_19, edge_41_20,
  input [6:0] edge_41_21, edge_41_22, edge_41_23, edge_41_24, edge_41_25, edge_41_26, edge_41_27, edge_41_28, edge_41_29, edge_41_30,
  input [6:0] edge_41_31, edge_41_32, edge_41_33, edge_41_34, edge_41_35, edge_41_36, edge_41_37, edge_41_38, edge_41_39, edge_41_40,
  input [6:0] edge_42_1, edge_42_2, edge_42_3, edge_42_4, edge_42_5, edge_42_6, edge_42_7, edge_42_8, edge_42_9, edge_42_10,
  input [6:0] edge_42_11, edge_42_12, edge_42_13, edge_42_14, edge_42_15, edge_42_16, edge_42_17, edge_42_18, edge_42_19, edge_42_20,
  input [6:0] edge_42_21, edge_42_22, edge_42_23, edge_42_24, edge_42_25, edge_42_26, edge_42_27, edge_42_28, edge_42_29, edge_42_30,
  input [6:0] edge_42_31, edge_42_32, edge_42_33, edge_42_34, edge_42_35, edge_42_36, edge_42_37, edge_42_38, edge_42_39, edge_42_40,
  input [6:0] edge_43_1, edge_43_2, edge_43_3, edge_43_4, edge_43_5, edge_43_6, edge_43_7, edge_43_8, edge_43_9, edge_43_10,
  input [6:0] edge_43_11, edge_43_12, edge_43_13, edge_43_14, edge_43_15, edge_43_16, edge_43_17, edge_43_18, edge_43_19, edge_43_20,
  input [6:0] edge_43_21, edge_43_22, edge_43_23, edge_43_24, edge_43_25, edge_43_26, edge_43_27, edge_43_28, edge_43_29, edge_43_30,
  input [6:0] edge_43_31, edge_43_32, edge_43_33, edge_43_34, edge_43_35, edge_43_36, edge_43_37, edge_43_38, edge_43_39, edge_43_40,
  input [6:0] edge_44_1, edge_44_2, edge_44_3, edge_44_4, edge_44_5, edge_44_6, edge_44_7, edge_44_8, edge_44_9, edge_44_10,
  input [6:0] edge_44_11, edge_44_12, edge_44_13, edge_44_14, edge_44_15, edge_44_16, edge_44_17, edge_44_18, edge_44_19, edge_44_20,
  input [6:0] edge_44_21, edge_44_22, edge_44_23, edge_44_24, edge_44_25, edge_44_26, edge_44_27, edge_44_28, edge_44_29, edge_44_30,
  input [6:0] edge_44_31, edge_44_32, edge_44_33, edge_44_34, edge_44_35, edge_44_36, edge_44_37, edge_44_38, edge_44_39, edge_44_40,
  input [6:0] edge_45_1, edge_45_2, edge_45_3, edge_45_4, edge_45_5, edge_45_6, edge_45_7, edge_45_8, edge_45_9, edge_45_10,
  input [6:0] edge_45_11, edge_45_12, edge_45_13, edge_45_14, edge_45_15, edge_45_16, edge_45_17, edge_45_18, edge_45_19, edge_45_20,
  input [6:0] edge_45_21, edge_45_22, edge_45_23, edge_45_24, edge_45_25, edge_45_26, edge_45_27, edge_45_28, edge_45_29, edge_45_30,
  input [6:0] edge_45_31, edge_45_32, edge_45_33, edge_45_34, edge_45_35, edge_45_36, edge_45_37, edge_45_38, edge_45_39, edge_45_40,
  input [6:0] edge_46_1, edge_46_2, edge_46_3, edge_46_4, edge_46_5, edge_46_6, edge_46_7, edge_46_8, edge_46_9, edge_46_10,
  input [6:0] edge_46_11, edge_46_12, edge_46_13, edge_46_14, edge_46_15, edge_46_16, edge_46_17, edge_46_18, edge_46_19, edge_46_20,
  input [6:0] edge_46_21, edge_46_22, edge_46_23, edge_46_24, edge_46_25, edge_46_26, edge_46_27, edge_46_28, edge_46_29, edge_46_30,
  input [6:0] edge_46_31, edge_46_32, edge_46_33, edge_46_34, edge_46_35, edge_46_36, edge_46_37, edge_46_38, edge_46_39, edge_46_40,
  input [6:0] edge_47_1, edge_47_2, edge_47_3, edge_47_4, edge_47_5, edge_47_6, edge_47_7, edge_47_8, edge_47_9, edge_47_10,
  input [6:0] edge_47_11, edge_47_12, edge_47_13, edge_47_14, edge_47_15, edge_47_16, edge_47_17, edge_47_18, edge_47_19, edge_47_20,
  input [6:0] edge_47_21, edge_47_22, edge_47_23, edge_47_24, edge_47_25, edge_47_26, edge_47_27, edge_47_28, edge_47_29, edge_47_30,
  input [6:0] edge_47_31, edge_47_32, edge_47_33, edge_47_34, edge_47_35, edge_47_36, edge_47_37, edge_47_38, edge_47_39, edge_47_40,
  input [6:0] edge_48_1, edge_48_2, edge_48_3, edge_48_4, edge_48_5, edge_48_6, edge_48_7, edge_48_8, edge_48_9, edge_48_10,
  input [6:0] edge_48_11, edge_48_12, edge_48_13, edge_48_14, edge_48_15, edge_48_16, edge_48_17, edge_48_18, edge_48_19, edge_48_20,
  input [6:0] edge_48_21, edge_48_22, edge_48_23, edge_48_24, edge_48_25, edge_48_26, edge_48_27, edge_48_28, edge_48_29, edge_48_30,
  input [6:0] edge_48_31, edge_48_32, edge_48_33, edge_48_34, edge_48_35, edge_48_36, edge_48_37, edge_48_38, edge_48_39, edge_48_40,
  input [6:0] edge_49_1, edge_49_2, edge_49_3, edge_49_4, edge_49_5, edge_49_6, edge_49_7, edge_49_8, edge_49_9, edge_49_10,
  input [6:0] edge_49_11, edge_49_12, edge_49_13, edge_49_14, edge_49_15, edge_49_16, edge_49_17, edge_49_18, edge_49_19, edge_49_20,
  input [6:0] edge_49_21, edge_49_22, edge_49_23, edge_49_24, edge_49_25, edge_49_26, edge_49_27, edge_49_28, edge_49_29, edge_49_30,
  input [6:0] edge_49_31, edge_49_32, edge_49_33, edge_49_34, edge_49_35, edge_49_36, edge_49_37, edge_49_38, edge_49_39, edge_49_40,
  input [6:0] edge_50_1, edge_50_2, edge_50_3, edge_50_4, edge_50_5, edge_50_6, edge_50_7, edge_50_8, edge_50_9, edge_50_10,
  input [6:0] edge_50_11, edge_50_12, edge_50_13, edge_50_14, edge_50_15, edge_50_16, edge_50_17, edge_50_18, edge_50_19, edge_50_20,
  input [6:0] edge_50_21, edge_50_22, edge_50_23, edge_50_24, edge_50_25, edge_50_26, edge_50_27, edge_50_28, edge_50_29, edge_50_30,
  input [6:0] edge_50_31, edge_50_32, edge_50_33, edge_50_34, edge_50_35, edge_50_36, edge_50_37, edge_50_38, edge_50_39, edge_50_40,
  input [6:0] edge_51_1, edge_51_2, edge_51_3, edge_51_4, edge_51_5, edge_51_6, edge_51_7, edge_51_8, edge_51_9, edge_51_10,
  input [6:0] edge_51_11, edge_51_12, edge_51_13, edge_51_14, edge_51_15, edge_51_16, edge_51_17, edge_51_18, edge_51_19, edge_51_20,
  input [6:0] edge_51_21, edge_51_22, edge_51_23, edge_51_24, edge_51_25, edge_51_26, edge_51_27, edge_51_28, edge_51_29, edge_51_30,
  input [6:0] edge_51_31, edge_51_32, edge_51_33, edge_51_34, edge_51_35, edge_51_36, edge_51_37, edge_51_38, edge_51_39, edge_51_40,
  input [6:0] edge_52_1, edge_52_2, edge_52_3, edge_52_4, edge_52_5, edge_52_6, edge_52_7, edge_52_8, edge_52_9, edge_52_10,
  input [6:0] edge_52_11, edge_52_12, edge_52_13, edge_52_14, edge_52_15, edge_52_16, edge_52_17, edge_52_18, edge_52_19, edge_52_20,
  input [6:0] edge_52_21, edge_52_22, edge_52_23, edge_52_24, edge_52_25, edge_52_26, edge_52_27, edge_52_28, edge_52_29, edge_52_30,
  input [6:0] edge_52_31, edge_52_32, edge_52_33, edge_52_34, edge_52_35, edge_52_36, edge_52_37, edge_52_38, edge_52_39, edge_52_40,
  input [6:0] edge_53_1, edge_53_2, edge_53_3, edge_53_4, edge_53_5, edge_53_6, edge_53_7, edge_53_8, edge_53_9, edge_53_10,
  input [6:0] edge_53_11, edge_53_12, edge_53_13, edge_53_14, edge_53_15, edge_53_16, edge_53_17, edge_53_18, edge_53_19, edge_53_20,
  input [6:0] edge_53_21, edge_53_22, edge_53_23, edge_53_24, edge_53_25, edge_53_26, edge_53_27, edge_53_28, edge_53_29, edge_53_30,
  input [6:0] edge_53_31, edge_53_32, edge_53_33, edge_53_34, edge_53_35, edge_53_36, edge_53_37, edge_53_38, edge_53_39, edge_53_40,
  input [6:0] edge_54_1, edge_54_2, edge_54_3, edge_54_4, edge_54_5, edge_54_6, edge_54_7, edge_54_8, edge_54_9, edge_54_10,
  input [6:0] edge_54_11, edge_54_12, edge_54_13, edge_54_14, edge_54_15, edge_54_16, edge_54_17, edge_54_18, edge_54_19, edge_54_20,
  input [6:0] edge_54_21, edge_54_22, edge_54_23, edge_54_24, edge_54_25, edge_54_26, edge_54_27, edge_54_28, edge_54_29, edge_54_30,
  input [6:0] edge_54_31, edge_54_32, edge_54_33, edge_54_34, edge_54_35, edge_54_36, edge_54_37, edge_54_38, edge_54_39, edge_54_40,
  input [6:0] edge_55_1, edge_55_2, edge_55_3, edge_55_4, edge_55_5, edge_55_6, edge_55_7, edge_55_8, edge_55_9, edge_55_10,
  input [6:0] edge_55_11, edge_55_12, edge_55_13, edge_55_14, edge_55_15, edge_55_16, edge_55_17, edge_55_18, edge_55_19, edge_55_20,
  input [6:0] edge_55_21, edge_55_22, edge_55_23, edge_55_24, edge_55_25, edge_55_26, edge_55_27, edge_55_28, edge_55_29, edge_55_30,
  input [6:0] edge_55_31, edge_55_32, edge_55_33, edge_55_34, edge_55_35, edge_55_36, edge_55_37, edge_55_38, edge_55_39, edge_55_40,
  input [6:0] edge_56_1, edge_56_2, edge_56_3, edge_56_4, edge_56_5, edge_56_6, edge_56_7, edge_56_8, edge_56_9, edge_56_10,
  input [6:0] edge_56_11, edge_56_12, edge_56_13, edge_56_14, edge_56_15, edge_56_16, edge_56_17, edge_56_18, edge_56_19, edge_56_20,
  input [6:0] edge_56_21, edge_56_22, edge_56_23, edge_56_24, edge_56_25, edge_56_26, edge_56_27, edge_56_28, edge_56_29, edge_56_30,
  input [6:0] edge_56_31, edge_56_32, edge_56_33, edge_56_34, edge_56_35, edge_56_36, edge_56_37, edge_56_38, edge_56_39, edge_56_40,
  input [6:0] edge_57_1, edge_57_2, edge_57_3, edge_57_4, edge_57_5, edge_57_6, edge_57_7, edge_57_8, edge_57_9, edge_57_10,
  input [6:0] edge_57_11, edge_57_12, edge_57_13, edge_57_14, edge_57_15, edge_57_16, edge_57_17, edge_57_18, edge_57_19, edge_57_20,
  input [6:0] edge_57_21, edge_57_22, edge_57_23, edge_57_24, edge_57_25, edge_57_26, edge_57_27, edge_57_28, edge_57_29, edge_57_30,
  input [6:0] edge_57_31, edge_57_32, edge_57_33, edge_57_34, edge_57_35, edge_57_36, edge_57_37, edge_57_38, edge_57_39, edge_57_40,
  input [6:0] edge_58_1, edge_58_2, edge_58_3, edge_58_4, edge_58_5, edge_58_6, edge_58_7, edge_58_8, edge_58_9, edge_58_10,
  input [6:0] edge_58_11, edge_58_12, edge_58_13, edge_58_14, edge_58_15, edge_58_16, edge_58_17, edge_58_18, edge_58_19, edge_58_20,
  input [6:0] edge_58_21, edge_58_22, edge_58_23, edge_58_24, edge_58_25, edge_58_26, edge_58_27, edge_58_28, edge_58_29, edge_58_30,
  input [6:0] edge_58_31, edge_58_32, edge_58_33, edge_58_34, edge_58_35, edge_58_36, edge_58_37, edge_58_38, edge_58_39, edge_58_40,
  input [6:0] edge_59_1, edge_59_2, edge_59_3, edge_59_4, edge_59_5, edge_59_6, edge_59_7, edge_59_8, edge_59_9, edge_59_10,
  input [6:0] edge_59_11, edge_59_12, edge_59_13, edge_59_14, edge_59_15, edge_59_16, edge_59_17, edge_59_18, edge_59_19, edge_59_20,
  input [6:0] edge_59_21, edge_59_22, edge_59_23, edge_59_24, edge_59_25, edge_59_26, edge_59_27, edge_59_28, edge_59_29, edge_59_30,
  input [6:0] edge_59_31, edge_59_32, edge_59_33, edge_59_34, edge_59_35, edge_59_36, edge_59_37, edge_59_38, edge_59_39, edge_59_40,
  input [6:0] edge_60_1, edge_60_2, edge_60_3, edge_60_4, edge_60_5, edge_60_6, edge_60_7, edge_60_8, edge_60_9, edge_60_10,
  input [6:0] edge_60_11, edge_60_12, edge_60_13, edge_60_14, edge_60_15, edge_60_16, edge_60_17, edge_60_18, edge_60_19, edge_60_20,
  input [6:0] edge_60_21, edge_60_22, edge_60_23, edge_60_24, edge_60_25, edge_60_26, edge_60_27, edge_60_28, edge_60_29, edge_60_30,
  input [6:0] edge_60_31, edge_60_32, edge_60_33, edge_60_34, edge_60_35, edge_60_36, edge_60_37, edge_60_38, edge_60_39, edge_60_40,
  input [6:0] edge_61_1, edge_61_2, edge_61_3, edge_61_4, edge_61_5, edge_61_6, edge_61_7, edge_61_8, edge_61_9, edge_61_10,
  input [6:0] edge_61_11, edge_61_12, edge_61_13, edge_61_14, edge_61_15, edge_61_16, edge_61_17, edge_61_18, edge_61_19, edge_61_20,
  input [6:0] edge_61_21, edge_61_22, edge_61_23, edge_61_24, edge_61_25, edge_61_26, edge_61_27, edge_61_28, edge_61_29, edge_61_30,
  input [6:0] edge_61_31, edge_61_32, edge_61_33, edge_61_34, edge_61_35, edge_61_36, edge_61_37, edge_61_38, edge_61_39, edge_61_40,
  input [6:0] edge_62_1, edge_62_2, edge_62_3, edge_62_4, edge_62_5, edge_62_6, edge_62_7, edge_62_8, edge_62_9, edge_62_10,
  input [6:0] edge_62_11, edge_62_12, edge_62_13, edge_62_14, edge_62_15, edge_62_16, edge_62_17, edge_62_18, edge_62_19, edge_62_20,
  input [6:0] edge_62_21, edge_62_22, edge_62_23, edge_62_24, edge_62_25, edge_62_26, edge_62_27, edge_62_28, edge_62_29, edge_62_30,
  input [6:0] edge_62_31, edge_62_32, edge_62_33, edge_62_34, edge_62_35, edge_62_36, edge_62_37, edge_62_38, edge_62_39, edge_62_40,
  input [6:0] edge_63_1, edge_63_2, edge_63_3, edge_63_4, edge_63_5, edge_63_6, edge_63_7, edge_63_8, edge_63_9, edge_63_10,
  input [6:0] edge_63_11, edge_63_12, edge_63_13, edge_63_14, edge_63_15, edge_63_16, edge_63_17, edge_63_18, edge_63_19, edge_63_20,
  input [6:0] edge_63_21, edge_63_22, edge_63_23, edge_63_24, edge_63_25, edge_63_26, edge_63_27, edge_63_28, edge_63_29, edge_63_30,
  input [6:0] edge_63_31, edge_63_32, edge_63_33, edge_63_34, edge_63_35, edge_63_36, edge_63_37, edge_63_38, edge_63_39, edge_63_40,
  input [6:0] edge_64_1, edge_64_2, edge_64_3, edge_64_4, edge_64_5, edge_64_6, edge_64_7, edge_64_8, edge_64_9, edge_64_10,
  input [6:0] edge_64_11, edge_64_12, edge_64_13, edge_64_14, edge_64_15, edge_64_16, edge_64_17, edge_64_18, edge_64_19, edge_64_20,
  input [6:0] edge_64_21, edge_64_22, edge_64_23, edge_64_24, edge_64_25, edge_64_26, edge_64_27, edge_64_28, edge_64_29, edge_64_30,
  input [6:0] edge_64_31, edge_64_32, edge_64_33, edge_64_34, edge_64_35, edge_64_36, edge_64_37, edge_64_38, edge_64_39, edge_64_40,
  input [6:0] edge_65_1, edge_65_2, edge_65_3, edge_65_4, edge_65_5, edge_65_6, edge_65_7, edge_65_8, edge_65_9, edge_65_10,
  input [6:0] edge_65_11, edge_65_12, edge_65_13, edge_65_14, edge_65_15, edge_65_16, edge_65_17, edge_65_18, edge_65_19, edge_65_20,
  input [6:0] edge_65_21, edge_65_22, edge_65_23, edge_65_24, edge_65_25, edge_65_26, edge_65_27, edge_65_28, edge_65_29, edge_65_30,
  input [6:0] edge_65_31, edge_65_32, edge_65_33, edge_65_34, edge_65_35, edge_65_36, edge_65_37, edge_65_38, edge_65_39, edge_65_40,
  input [6:0] edge_66_1, edge_66_2, edge_66_3, edge_66_4, edge_66_5, edge_66_6, edge_66_7, edge_66_8, edge_66_9, edge_66_10,
  input [6:0] edge_66_11, edge_66_12, edge_66_13, edge_66_14, edge_66_15, edge_66_16, edge_66_17, edge_66_18, edge_66_19, edge_66_20,
  input [6:0] edge_66_21, edge_66_22, edge_66_23, edge_66_24, edge_66_25, edge_66_26, edge_66_27, edge_66_28, edge_66_29, edge_66_30,
  input [6:0] edge_66_31, edge_66_32, edge_66_33, edge_66_34, edge_66_35, edge_66_36, edge_66_37, edge_66_38, edge_66_39, edge_66_40,
  input [6:0] edge_67_1, edge_67_2, edge_67_3, edge_67_4, edge_67_5, edge_67_6, edge_67_7, edge_67_8, edge_67_9, edge_67_10,
  input [6:0] edge_67_11, edge_67_12, edge_67_13, edge_67_14, edge_67_15, edge_67_16, edge_67_17, edge_67_18, edge_67_19, edge_67_20,
  input [6:0] edge_67_21, edge_67_22, edge_67_23, edge_67_24, edge_67_25, edge_67_26, edge_67_27, edge_67_28, edge_67_29, edge_67_30,
  input [6:0] edge_67_31, edge_67_32, edge_67_33, edge_67_34, edge_67_35, edge_67_36, edge_67_37, edge_67_38, edge_67_39, edge_67_40,
  input [6:0] edge_68_1, edge_68_2, edge_68_3, edge_68_4, edge_68_5, edge_68_6, edge_68_7, edge_68_8, edge_68_9, edge_68_10,
  input [6:0] edge_68_11, edge_68_12, edge_68_13, edge_68_14, edge_68_15, edge_68_16, edge_68_17, edge_68_18, edge_68_19, edge_68_20,
  input [6:0] edge_68_21, edge_68_22, edge_68_23, edge_68_24, edge_68_25, edge_68_26, edge_68_27, edge_68_28, edge_68_29, edge_68_30,
  input [6:0] edge_68_31, edge_68_32, edge_68_33, edge_68_34, edge_68_35, edge_68_36, edge_68_37, edge_68_38, edge_68_39, edge_68_40,
  input [6:0] edge_69_1, edge_69_2, edge_69_3, edge_69_4, edge_69_5, edge_69_6, edge_69_7, edge_69_8, edge_69_9, edge_69_10,
  input [6:0] edge_69_11, edge_69_12, edge_69_13, edge_69_14, edge_69_15, edge_69_16, edge_69_17, edge_69_18, edge_69_19, edge_69_20,
  input [6:0] edge_69_21, edge_69_22, edge_69_23, edge_69_24, edge_69_25, edge_69_26, edge_69_27, edge_69_28, edge_69_29, edge_69_30,
  input [6:0] edge_69_31, edge_69_32, edge_69_33, edge_69_34, edge_69_35, edge_69_36, edge_69_37, edge_69_38, edge_69_39, edge_69_40,
  input [6:0] edge_70_1, edge_70_2, edge_70_3, edge_70_4, edge_70_5, edge_70_6, edge_70_7, edge_70_8, edge_70_9, edge_70_10,
  input [6:0] edge_70_11, edge_70_12, edge_70_13, edge_70_14, edge_70_15, edge_70_16, edge_70_17, edge_70_18, edge_70_19, edge_70_20,
  input [6:0] edge_70_21, edge_70_22, edge_70_23, edge_70_24, edge_70_25, edge_70_26, edge_70_27, edge_70_28, edge_70_29, edge_70_30,
  input [6:0] edge_70_31, edge_70_32, edge_70_33, edge_70_34, edge_70_35, edge_70_36, edge_70_37, edge_70_38, edge_70_39, edge_70_40,
  input [6:0] edge_71_1, edge_71_2, edge_71_3, edge_71_4, edge_71_5, edge_71_6, edge_71_7, edge_71_8, edge_71_9, edge_71_10,
  input [6:0] edge_71_11, edge_71_12, edge_71_13, edge_71_14, edge_71_15, edge_71_16, edge_71_17, edge_71_18, edge_71_19, edge_71_20,
  input [6:0] edge_71_21, edge_71_22, edge_71_23, edge_71_24, edge_71_25, edge_71_26, edge_71_27, edge_71_28, edge_71_29, edge_71_30,
  input [6:0] edge_71_31, edge_71_32, edge_71_33, edge_71_34, edge_71_35, edge_71_36, edge_71_37, edge_71_38, edge_71_39, edge_71_40,
  input [6:0] edge_72_1, edge_72_2, edge_72_3, edge_72_4, edge_72_5, edge_72_6, edge_72_7, edge_72_8, edge_72_9, edge_72_10,
  input [6:0] edge_72_11, edge_72_12, edge_72_13, edge_72_14, edge_72_15, edge_72_16, edge_72_17, edge_72_18, edge_72_19, edge_72_20,
  input [6:0] edge_72_21, edge_72_22, edge_72_23, edge_72_24, edge_72_25, edge_72_26, edge_72_27, edge_72_28, edge_72_29, edge_72_30,
  input [6:0] edge_72_31, edge_72_32, edge_72_33, edge_72_34, edge_72_35, edge_72_36, edge_72_37, edge_72_38, edge_72_39, edge_72_40,
  input [6:0] edge_73_1, edge_73_2, edge_73_3, edge_73_4, edge_73_5, edge_73_6, edge_73_7, edge_73_8, edge_73_9, edge_73_10,
  input [6:0] edge_73_11, edge_73_12, edge_73_13, edge_73_14, edge_73_15, edge_73_16, edge_73_17, edge_73_18, edge_73_19, edge_73_20,
  input [6:0] edge_73_21, edge_73_22, edge_73_23, edge_73_24, edge_73_25, edge_73_26, edge_73_27, edge_73_28, edge_73_29, edge_73_30,
  input [6:0] edge_73_31, edge_73_32, edge_73_33, edge_73_34, edge_73_35, edge_73_36, edge_73_37, edge_73_38, edge_73_39, edge_73_40,
  input [6:0] edge_74_1, edge_74_2, edge_74_3, edge_74_4, edge_74_5, edge_74_6, edge_74_7, edge_74_8, edge_74_9, edge_74_10,
  input [6:0] edge_74_11, edge_74_12, edge_74_13, edge_74_14, edge_74_15, edge_74_16, edge_74_17, edge_74_18, edge_74_19, edge_74_20,
  input [6:0] edge_74_21, edge_74_22, edge_74_23, edge_74_24, edge_74_25, edge_74_26, edge_74_27, edge_74_28, edge_74_29, edge_74_30,
  input [6:0] edge_74_31, edge_74_32, edge_74_33, edge_74_34, edge_74_35, edge_74_36, edge_74_37, edge_74_38, edge_74_39, edge_74_40,
  input [6:0] edge_75_1, edge_75_2, edge_75_3, edge_75_4, edge_75_5, edge_75_6, edge_75_7, edge_75_8, edge_75_9, edge_75_10,
  input [6:0] edge_75_11, edge_75_12, edge_75_13, edge_75_14, edge_75_15, edge_75_16, edge_75_17, edge_75_18, edge_75_19, edge_75_20,
  input [6:0] edge_75_21, edge_75_22, edge_75_23, edge_75_24, edge_75_25, edge_75_26, edge_75_27, edge_75_28, edge_75_29, edge_75_30,
  input [6:0] edge_75_31, edge_75_32, edge_75_33, edge_75_34, edge_75_35, edge_75_36, edge_75_37, edge_75_38, edge_75_39, edge_75_40,
  input [6:0] edge_76_1, edge_76_2, edge_76_3, edge_76_4, edge_76_5, edge_76_6, edge_76_7, edge_76_8, edge_76_9, edge_76_10,
  input [6:0] edge_76_11, edge_76_12, edge_76_13, edge_76_14, edge_76_15, edge_76_16, edge_76_17, edge_76_18, edge_76_19, edge_76_20,
  input [6:0] edge_76_21, edge_76_22, edge_76_23, edge_76_24, edge_76_25, edge_76_26, edge_76_27, edge_76_28, edge_76_29, edge_76_30,
  input [6:0] edge_76_31, edge_76_32, edge_76_33, edge_76_34, edge_76_35, edge_76_36, edge_76_37, edge_76_38, edge_76_39, edge_76_40,
  input [6:0] edge_77_1, edge_77_2, edge_77_3, edge_77_4, edge_77_5, edge_77_6, edge_77_7, edge_77_8, edge_77_9, edge_77_10,
  input [6:0] edge_77_11, edge_77_12, edge_77_13, edge_77_14, edge_77_15, edge_77_16, edge_77_17, edge_77_18, edge_77_19, edge_77_20,
  input [6:0] edge_77_21, edge_77_22, edge_77_23, edge_77_24, edge_77_25, edge_77_26, edge_77_27, edge_77_28, edge_77_29, edge_77_30,
  input [6:0] edge_77_31, edge_77_32, edge_77_33, edge_77_34, edge_77_35, edge_77_36, edge_77_37, edge_77_38, edge_77_39, edge_77_40,
  input [6:0] edge_78_1, edge_78_2, edge_78_3, edge_78_4, edge_78_5, edge_78_6, edge_78_7, edge_78_8, edge_78_9, edge_78_10,
  input [6:0] edge_78_11, edge_78_12, edge_78_13, edge_78_14, edge_78_15, edge_78_16, edge_78_17, edge_78_18, edge_78_19, edge_78_20,
  input [6:0] edge_78_21, edge_78_22, edge_78_23, edge_78_24, edge_78_25, edge_78_26, edge_78_27, edge_78_28, edge_78_29, edge_78_30,
  input [6:0] edge_78_31, edge_78_32, edge_78_33, edge_78_34, edge_78_35, edge_78_36, edge_78_37, edge_78_38, edge_78_39, edge_78_40,
  input [6:0] edge_79_1, edge_79_2, edge_79_3, edge_79_4, edge_79_5, edge_79_6, edge_79_7, edge_79_8, edge_79_9, edge_79_10,
  input [6:0] edge_79_11, edge_79_12, edge_79_13, edge_79_14, edge_79_15, edge_79_16, edge_79_17, edge_79_18, edge_79_19, edge_79_20,
  input [6:0] edge_79_21, edge_79_22, edge_79_23, edge_79_24, edge_79_25, edge_79_26, edge_79_27, edge_79_28, edge_79_29, edge_79_30,
  input [6:0] edge_79_31, edge_79_32, edge_79_33, edge_79_34, edge_79_35, edge_79_36, edge_79_37, edge_79_38, edge_79_39, edge_79_40,
  input [6:0] edge_80_1, edge_80_2, edge_80_3, edge_80_4, edge_80_5, edge_80_6, edge_80_7, edge_80_8, edge_80_9, edge_80_10,
  input [6:0] edge_80_11, edge_80_12, edge_80_13, edge_80_14, edge_80_15, edge_80_16, edge_80_17, edge_80_18, edge_80_19, edge_80_20,
  input [6:0] edge_80_21, edge_80_22, edge_80_23, edge_80_24, edge_80_25, edge_80_26, edge_80_27, edge_80_28, edge_80_29, edge_80_30,
  input [6:0] edge_80_31, edge_80_32, edge_80_33, edge_80_34, edge_80_35, edge_80_36, edge_80_37, edge_80_38, edge_80_39, edge_80_40,
  input [6:0] edge_81_1, edge_81_2, edge_81_3, edge_81_4, edge_81_5, edge_81_6, edge_81_7, edge_81_8, edge_81_9, edge_81_10,
  input [6:0] edge_81_11, edge_81_12, edge_81_13, edge_81_14, edge_81_15, edge_81_16, edge_81_17, edge_81_18, edge_81_19, edge_81_20,
  input [6:0] edge_81_21, edge_81_22, edge_81_23, edge_81_24, edge_81_25, edge_81_26, edge_81_27, edge_81_28, edge_81_29, edge_81_30,
  input [6:0] edge_81_31, edge_81_32, edge_81_33, edge_81_34, edge_81_35, edge_81_36, edge_81_37, edge_81_38, edge_81_39, edge_81_40,
  input [6:0] edge_82_1, edge_82_2, edge_82_3, edge_82_4, edge_82_5, edge_82_6, edge_82_7, edge_82_8, edge_82_9, edge_82_10,
  input [6:0] edge_82_11, edge_82_12, edge_82_13, edge_82_14, edge_82_15, edge_82_16, edge_82_17, edge_82_18, edge_82_19, edge_82_20,
  input [6:0] edge_82_21, edge_82_22, edge_82_23, edge_82_24, edge_82_25, edge_82_26, edge_82_27, edge_82_28, edge_82_29, edge_82_30,
  input [6:0] edge_82_31, edge_82_32, edge_82_33, edge_82_34, edge_82_35, edge_82_36, edge_82_37, edge_82_38, edge_82_39, edge_82_40,
  input [6:0] edge_83_1, edge_83_2, edge_83_3, edge_83_4, edge_83_5, edge_83_6, edge_83_7, edge_83_8, edge_83_9, edge_83_10,
  input [6:0] edge_83_11, edge_83_12, edge_83_13, edge_83_14, edge_83_15, edge_83_16, edge_83_17, edge_83_18, edge_83_19, edge_83_20,
  input [6:0] edge_83_21, edge_83_22, edge_83_23, edge_83_24, edge_83_25, edge_83_26, edge_83_27, edge_83_28, edge_83_29, edge_83_30,
  input [6:0] edge_83_31, edge_83_32, edge_83_33, edge_83_34, edge_83_35, edge_83_36, edge_83_37, edge_83_38, edge_83_39, edge_83_40,
  input [6:0] edge_84_1, edge_84_2, edge_84_3, edge_84_4, edge_84_5, edge_84_6, edge_84_7, edge_84_8, edge_84_9, edge_84_10,
  input [6:0] edge_84_11, edge_84_12, edge_84_13, edge_84_14, edge_84_15, edge_84_16, edge_84_17, edge_84_18, edge_84_19, edge_84_20,
  input [6:0] edge_84_21, edge_84_22, edge_84_23, edge_84_24, edge_84_25, edge_84_26, edge_84_27, edge_84_28, edge_84_29, edge_84_30,
  input [6:0] edge_84_31, edge_84_32, edge_84_33, edge_84_34, edge_84_35, edge_84_36, edge_84_37, edge_84_38, edge_84_39, edge_84_40,
  input [6:0] edge_85_1, edge_85_2, edge_85_3, edge_85_4, edge_85_5, edge_85_6, edge_85_7, edge_85_8, edge_85_9, edge_85_10,
  input [6:0] edge_85_11, edge_85_12, edge_85_13, edge_85_14, edge_85_15, edge_85_16, edge_85_17, edge_85_18, edge_85_19, edge_85_20,
  input [6:0] edge_85_21, edge_85_22, edge_85_23, edge_85_24, edge_85_25, edge_85_26, edge_85_27, edge_85_28, edge_85_29, edge_85_30,
  input [6:0] edge_85_31, edge_85_32, edge_85_33, edge_85_34, edge_85_35, edge_85_36, edge_85_37, edge_85_38, edge_85_39, edge_85_40,
  input [6:0] edge_86_1, edge_86_2, edge_86_3, edge_86_4, edge_86_5, edge_86_6, edge_86_7, edge_86_8, edge_86_9, edge_86_10,
  input [6:0] edge_86_11, edge_86_12, edge_86_13, edge_86_14, edge_86_15, edge_86_16, edge_86_17, edge_86_18, edge_86_19, edge_86_20,
  input [6:0] edge_86_21, edge_86_22, edge_86_23, edge_86_24, edge_86_25, edge_86_26, edge_86_27, edge_86_28, edge_86_29, edge_86_30,
  input [6:0] edge_86_31, edge_86_32, edge_86_33, edge_86_34, edge_86_35, edge_86_36, edge_86_37, edge_86_38, edge_86_39, edge_86_40,
  input [6:0] edge_87_1, edge_87_2, edge_87_3, edge_87_4, edge_87_5, edge_87_6, edge_87_7, edge_87_8, edge_87_9, edge_87_10,
  input [6:0] edge_87_11, edge_87_12, edge_87_13, edge_87_14, edge_87_15, edge_87_16, edge_87_17, edge_87_18, edge_87_19, edge_87_20,
  input [6:0] edge_87_21, edge_87_22, edge_87_23, edge_87_24, edge_87_25, edge_87_26, edge_87_27, edge_87_28, edge_87_29, edge_87_30,
  input [6:0] edge_87_31, edge_87_32, edge_87_33, edge_87_34, edge_87_35, edge_87_36, edge_87_37, edge_87_38, edge_87_39, edge_87_40,
  input [6:0] edge_88_1, edge_88_2, edge_88_3, edge_88_4, edge_88_5, edge_88_6, edge_88_7, edge_88_8, edge_88_9, edge_88_10,
  input [6:0] edge_88_11, edge_88_12, edge_88_13, edge_88_14, edge_88_15, edge_88_16, edge_88_17, edge_88_18, edge_88_19, edge_88_20,
  input [6:0] edge_88_21, edge_88_22, edge_88_23, edge_88_24, edge_88_25, edge_88_26, edge_88_27, edge_88_28, edge_88_29, edge_88_30,
  input [6:0] edge_88_31, edge_88_32, edge_88_33, edge_88_34, edge_88_35, edge_88_36, edge_88_37, edge_88_38, edge_88_39, edge_88_40,
  input [6:0] edge_89_1, edge_89_2, edge_89_3, edge_89_4, edge_89_5, edge_89_6, edge_89_7, edge_89_8, edge_89_9, edge_89_10,
  input [6:0] edge_89_11, edge_89_12, edge_89_13, edge_89_14, edge_89_15, edge_89_16, edge_89_17, edge_89_18, edge_89_19, edge_89_20,
  input [6:0] edge_89_21, edge_89_22, edge_89_23, edge_89_24, edge_89_25, edge_89_26, edge_89_27, edge_89_28, edge_89_29, edge_89_30,
  input [6:0] edge_89_31, edge_89_32, edge_89_33, edge_89_34, edge_89_35, edge_89_36, edge_89_37, edge_89_38, edge_89_39, edge_89_40,
  input [6:0] edge_90_1, edge_90_2, edge_90_3, edge_90_4, edge_90_5, edge_90_6, edge_90_7, edge_90_8, edge_90_9, edge_90_10,
  input [6:0] edge_90_11, edge_90_12, edge_90_13, edge_90_14, edge_90_15, edge_90_16, edge_90_17, edge_90_18, edge_90_19, edge_90_20,
  input [6:0] edge_90_21, edge_90_22, edge_90_23, edge_90_24, edge_90_25, edge_90_26, edge_90_27, edge_90_28, edge_90_29, edge_90_30,
  input [6:0] edge_90_31, edge_90_32, edge_90_33, edge_90_34, edge_90_35, edge_90_36, edge_90_37, edge_90_38, edge_90_39, edge_90_40,
  input [6:0] edge_91_1, edge_91_2, edge_91_3, edge_91_4, edge_91_5, edge_91_6, edge_91_7, edge_91_8, edge_91_9, edge_91_10,
  input [6:0] edge_91_11, edge_91_12, edge_91_13, edge_91_14, edge_91_15, edge_91_16, edge_91_17, edge_91_18, edge_91_19, edge_91_20,
  input [6:0] edge_91_21, edge_91_22, edge_91_23, edge_91_24, edge_91_25, edge_91_26, edge_91_27, edge_91_28, edge_91_29, edge_91_30,
  input [6:0] edge_91_31, edge_91_32, edge_91_33, edge_91_34, edge_91_35, edge_91_36, edge_91_37, edge_91_38, edge_91_39, edge_91_40,
  input [6:0] edge_92_1, edge_92_2, edge_92_3, edge_92_4, edge_92_5, edge_92_6, edge_92_7, edge_92_8, edge_92_9, edge_92_10,
  input [6:0] edge_92_11, edge_92_12, edge_92_13, edge_92_14, edge_92_15, edge_92_16, edge_92_17, edge_92_18, edge_92_19, edge_92_20,
  input [6:0] edge_92_21, edge_92_22, edge_92_23, edge_92_24, edge_92_25, edge_92_26, edge_92_27, edge_92_28, edge_92_29, edge_92_30,
  input [6:0] edge_92_31, edge_92_32, edge_92_33, edge_92_34, edge_92_35, edge_92_36, edge_92_37, edge_92_38, edge_92_39, edge_92_40,
  input [6:0] edge_93_1, edge_93_2, edge_93_3, edge_93_4, edge_93_5, edge_93_6, edge_93_7, edge_93_8, edge_93_9, edge_93_10,
  input [6:0] edge_93_11, edge_93_12, edge_93_13, edge_93_14, edge_93_15, edge_93_16, edge_93_17, edge_93_18, edge_93_19, edge_93_20,
  input [6:0] edge_93_21, edge_93_22, edge_93_23, edge_93_24, edge_93_25, edge_93_26, edge_93_27, edge_93_28, edge_93_29, edge_93_30,
  input [6:0] edge_93_31, edge_93_32, edge_93_33, edge_93_34, edge_93_35, edge_93_36, edge_93_37, edge_93_38, edge_93_39, edge_93_40,
  input [6:0] edge_94_1, edge_94_2, edge_94_3, edge_94_4, edge_94_5, edge_94_6, edge_94_7, edge_94_8, edge_94_9, edge_94_10,
  input [6:0] edge_94_11, edge_94_12, edge_94_13, edge_94_14, edge_94_15, edge_94_16, edge_94_17, edge_94_18, edge_94_19, edge_94_20,
  input [6:0] edge_94_21, edge_94_22, edge_94_23, edge_94_24, edge_94_25, edge_94_26, edge_94_27, edge_94_28, edge_94_29, edge_94_30,
  input [6:0] edge_94_31, edge_94_32, edge_94_33, edge_94_34, edge_94_35, edge_94_36, edge_94_37, edge_94_38, edge_94_39, edge_94_40,
  input [6:0] edge_95_1, edge_95_2, edge_95_3, edge_95_4, edge_95_5, edge_95_6, edge_95_7, edge_95_8, edge_95_9, edge_95_10,
  input [6:0] edge_95_11, edge_95_12, edge_95_13, edge_95_14, edge_95_15, edge_95_16, edge_95_17, edge_95_18, edge_95_19, edge_95_20,
  input [6:0] edge_95_21, edge_95_22, edge_95_23, edge_95_24, edge_95_25, edge_95_26, edge_95_27, edge_95_28, edge_95_29, edge_95_30,
  input [6:0] edge_95_31, edge_95_32, edge_95_33, edge_95_34, edge_95_35, edge_95_36, edge_95_37, edge_95_38, edge_95_39, edge_95_40,
  input [6:0] edge_96_1, edge_96_2, edge_96_3, edge_96_4, edge_96_5, edge_96_6, edge_96_7, edge_96_8, edge_96_9, edge_96_10,
  input [6:0] edge_96_11, edge_96_12, edge_96_13, edge_96_14, edge_96_15, edge_96_16, edge_96_17, edge_96_18, edge_96_19, edge_96_20,
  input [6:0] edge_96_21, edge_96_22, edge_96_23, edge_96_24, edge_96_25, edge_96_26, edge_96_27, edge_96_28, edge_96_29, edge_96_30,
  input [6:0] edge_96_31, edge_96_32, edge_96_33, edge_96_34, edge_96_35, edge_96_36, edge_96_37, edge_96_38, edge_96_39, edge_96_40,
  input [6:0] edge_97_1, edge_97_2, edge_97_3, edge_97_4, edge_97_5, edge_97_6, edge_97_7, edge_97_8, edge_97_9, edge_97_10,
  input [6:0] edge_97_11, edge_97_12, edge_97_13, edge_97_14, edge_97_15, edge_97_16, edge_97_17, edge_97_18, edge_97_19, edge_97_20,
  input [6:0] edge_97_21, edge_97_22, edge_97_23, edge_97_24, edge_97_25, edge_97_26, edge_97_27, edge_97_28, edge_97_29, edge_97_30,
  input [6:0] edge_97_31, edge_97_32, edge_97_33, edge_97_34, edge_97_35, edge_97_36, edge_97_37, edge_97_38, edge_97_39, edge_97_40,
  input [6:0] edge_98_1, edge_98_2, edge_98_3, edge_98_4, edge_98_5, edge_98_6, edge_98_7, edge_98_8, edge_98_9, edge_98_10,
  input [6:0] edge_98_11, edge_98_12, edge_98_13, edge_98_14, edge_98_15, edge_98_16, edge_98_17, edge_98_18, edge_98_19, edge_98_20,
  input [6:0] edge_98_21, edge_98_22, edge_98_23, edge_98_24, edge_98_25, edge_98_26, edge_98_27, edge_98_28, edge_98_29, edge_98_30,
  input [6:0] edge_98_31, edge_98_32, edge_98_33, edge_98_34, edge_98_35, edge_98_36, edge_98_37, edge_98_38, edge_98_39, edge_98_40,
  input [6:0] edge_99_1, edge_99_2, edge_99_3, edge_99_4, edge_99_5, edge_99_6, edge_99_7, edge_99_8, edge_99_9, edge_99_10,
  input [6:0] edge_99_11, edge_99_12, edge_99_13, edge_99_14, edge_99_15, edge_99_16, edge_99_17, edge_99_18, edge_99_19, edge_99_20,
  input [6:0] edge_99_21, edge_99_22, edge_99_23, edge_99_24, edge_99_25, edge_99_26, edge_99_27, edge_99_28, edge_99_29, edge_99_30,
  input [6:0] edge_99_31, edge_99_32, edge_99_33, edge_99_34, edge_99_35, edge_99_36, edge_99_37, edge_99_38, edge_99_39, edge_99_40,
  input [6:0] edge_100_1, edge_100_2, edge_100_3, edge_100_4, edge_100_5, edge_100_6, edge_100_7, edge_100_8, edge_100_9, edge_100_10,
  input [6:0] edge_100_11, edge_100_12, edge_100_13, edge_100_14, edge_100_15, edge_100_16, edge_100_17, edge_100_18, edge_100_19, edge_100_20,
  input [6:0] edge_100_21, edge_100_22, edge_100_23, edge_100_24, edge_100_25, edge_100_26, edge_100_27, edge_100_28, edge_100_29, edge_100_30,
  input [6:0] edge_100_31, edge_100_32, edge_100_33, edge_100_34, edge_100_35, edge_100_36, edge_100_37, edge_100_38, edge_100_39, edge_100_40,
  input [4:0] artist_1, artist_2, artist_3, artist_4, artist_5, artist_6, artist_7, artist_8, artist_9, artist_10,
  input [4:0] artist_11, artist_12, artist_13, artist_14, artist_15, artist_16, artist_17, artist_18, artist_19, artist_20,
  input [4:0] artist_21, artist_22, artist_23, artist_24, artist_25, artist_26, artist_27, artist_28, artist_29, artist_30,
  input [4:0] artist_31, artist_32, artist_33, artist_34, artist_35, artist_36, artist_37, artist_38, artist_39, artist_40,
  input [4:0] artist_41, artist_42, artist_43, artist_44, artist_45, artist_46, artist_47, artist_48, artist_49, artist_50,
  input [4:0] artist_51, artist_52, artist_53, artist_54, artist_55, artist_56, artist_57, artist_58, artist_59, artist_60,
  input [4:0] artist_61, artist_62, artist_63, artist_64, artist_65, artist_66, artist_67, artist_68, artist_69, artist_70,
  input [4:0] artist_71, artist_72, artist_73, artist_74, artist_75, artist_76, artist_77, artist_78, artist_79, artist_80,
  input [4:0] artist_81, artist_82, artist_83, artist_84, artist_85, artist_86, artist_87, artist_88, artist_89, artist_90,
  input [4:0] artist_91, artist_92, artist_93, artist_94, artist_95, artist_96, artist_97, artist_98, artist_99, artist_100,
  output reg found,
  output reg [6:0] song_1, song_2, song_3, song_4, song_5, song_6, song_7, song_8, song_9,
  output reg searching
);

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] INIT_START = 3'b001;
localparam [2:0] SEARCH = 3'b010;
localparam [2:0] CHECK_EDGE = 3'b011;
localparam [2:0] FOUND = 3'b100;
localparam [2:0] FAIL = 3'b101;

// Registers
reg [2:0] state;
reg [6:0] current_node;
reg [6:0] next_node;
reg [6:0] depth;
reg [6:0] start_node;
reg [6:0] edge_index;
reg [25:0] artist_mask;
reg [6:0] path [0:8];
reg [6:0] num_edges [1:100];
reg [6:0] edge [1:100][1:40];
reg [4:0] artist [1:100];

// Initialize edge and artist arrays
integer i, j;
initial begin
  for (i = 1; i <= 100; i = i + 1) begin
    num_edges[i] = 0;
    for (j = 1; j <= 40; j = j + 1) begin
      edge[i][j] = 0;
    end
    artist[i] = 0;
  end
end

// Assign inputs to arrays
always @(*) begin
  num_edges[1] = num_edges_1; num_edges[2] = num_edges_2; num_edges[3] = num_edges_3; num_edges[4] = num_edges_4; num_edges[5] = num_edges_5;
  num_edges[6] = num_edges_6; num_edges[7] = num_edges_7; num_edges[8] = num_edges_8; num_edges[9] = num_edges_9; num_edges[10] = num_edges_10;
  num_edges[11] = num_edges_11; num_edges[12] = num_edges_12; num_edges[13] = num_edges_13; num_edges[14] = num_edges_14; num_edges[15] = num_edges_15;
  num_edges[16] = num_edges_16; num_edges[17] = num_edges_17; num_edges[18] = num_edges_18; num_edges[19] = num_edges_19; num_edges[20] = num_edges_20;
  num_edges[21] = num_edges_21; num_edges[22] = num_edges_22; num_edges[23] = num_edges_23; num_edges[24] = num_edges_24; num_edges[25] = num_edges_25;
  num_edges[26] = num_edges_26; num_edges[27] = num_edges_27; num_edges[28] = num_edges_28; num_edges[29] = num_edges_29; num_edges[30] = num_edges_30;
  num_edges[31] = num_edges_31; num_edges[32] = num_edges_32; num_edges[33] = num_edges_33; num_edges[34] = num_edges_34; num_edges[35] = num_edges_35;
  num_edges[36] = num_edges_36; num_edges[37] = num_edges_37; num_edges[38] = num_edges_38; num_edges[39] = num_edges_39; num_edges[40] = num_edges_40;
  num_edges[41] = num_edges_41; num_edges[42] = num_edges_42; num_edges[43] = num_edges_43; num_edges[44] = num_edges_44; num_edges[45] = num_edges_45;
  num_edges[46] = num_edges_46; num_edges[47] = num_edges_47; num_edges[48] = num_edges_48; num_edges[49] = num_edges_49; num_edges[50] = num_edges_50;
  num_edges[51] = num_edges_51; num_edges[52] = num_edges_52; num_edges[53] = num_edges_53; num_edges[54] = num_edges_54; num_edges[55] = num_edges_55;
  num_edges[56] = num_edges_56; num_edges[57] = num_edges_57; num_edges[58] = num_edges_58; num_edges[59] = num_edges_59; num_edges[60] = num_edges_60;
  num_edges[61] = num_edges_61; num_edges[62] = num_edges_62; num_edges[63] = num_edges_63; num_edges[64] = num_edges_64; num_edges[65] = num_edges_65;
  num_edges[66] = num_edges_66; num_edges[67] = num_edges_67; num_edges[68] = num_edges_68; num_edges[69] = num_edges_69; num_edges[70] = num_edges_70;
  num_edges[71] = num_edges_71; num_edges[72] = num_edges_72; num_edges[73] = num_edges_73; num_edges[74] = num_edges_74; num_edges[75] = num_edges_75;
  num_edges[76] = num_edges_76; num_edges[77] = num_edges_77; num_edges[78] = num_edges_78; num_edges[79] = num_edges_79; num_edges[80] = num_edges_80;
  num_edges[81] = num_edges_81; num_edges[82] = num_edges_82; num_edges[83] = num_edges_83; num_edges[84] = num_edges_84; num_edges[85] = num_edges_85;
  num_edges[86] = num_edges_86; num_edges[87] = num_edges_87; num_edges[88] = num_edges_88; num_edges[89] = num_edges_89; num_edges[90] = num_edges_90;
  num_edges[91] = num_edges_91; num_edges[92] = num_edges_92; num_edges[93] = num_edges_93; num_edges[94] = num_edges_94; num_edges[95] = num_edges_95;
  num_edges[96] = num_edges_96; num_edges[97] = num_edges_97; num_edges[98] = num_edges_98; num_edges[99] = num_edges_99; num_edges[100] = num_edges_100;

  edge[1][1] = edge_1_1; edge[1][2] = edge_1_2; edge[1][3] = edge_1_3; edge[1][4] = edge_1_4; edge[1][5] = edge_1_5;
  edge[1][6] = edge_1_6; edge[1][7] = edge_1_7; edge[1][8] = edge_1_8; edge[1][9] = edge_1_9; edge[1][10] = edge_1_10;
  edge[1][11] = edge_1_11; edge[1][12] = edge_1_12; edge[1][13] = edge_1_13; edge[1][14] = edge_1_14; edge[1][15] = edge_1_15;
  edge[1][16] = edge_1_16; edge[1][17] = edge_1_17; edge[1][18] = edge_1_18; edge[1][19] = edge_1_19; edge[1][20] = edge_1_20;
  edge[1][21] = edge_1_21; edge[1][22] = edge_1_22; edge[1][23] = edge_1_23; edge[1][24] = edge_1_24; edge[1][25] = edge_1_25;
  edge[1][26] = edge_1_26; edge[1][27] = edge_1_27; edge[1][28] = edge_1_28; edge[1][29] = edge_1_29; edge[1][30] = edge_1_30;
  edge[1][31] = edge_1_31; edge[1][32] = edge_1_32; edge[1][33] = edge_1_33; edge[1][34] = edge_1_34; edge[1][35] = edge_1_35;
  edge[1][36] = edge_1_36; edge[1][37] = edge_1_37; edge[1][38] = edge_1_38; edge[1][39] = edge_1_39; edge[1][40] = edge_1_40;

  edge[2][1] = edge_2_1; edge[2][2] = edge_2_2; edge[2][3] = edge_2_3; edge[2][4] = edge_2_4; edge[2][5] = edge_2_5;
  edge[2][6] = edge_2_6; edge[2][7] = edge_2_7; edge[2][8] = edge_2_8; edge[2][9] = edge_2_9; edge[2][10] = edge_2_10;
  edge[2][11] = edge_2_11; edge[2][12] = edge_2_12; edge[2][13] = edge_2_13; edge[2][14] = edge_2_14; edge[2][15] = edge_2_15;
  edge[2][16] = edge_2_16; edge[2][17] = edge_2_17; edge[2][18] = edge_2_18; edge[2][19] = edge_2_19; edge[2][20] = edge_2_20;
  edge[2][21] = edge_2_21; edge[2][22] = edge_2_22; edge[2][23] = edge_2_23; edge[2][24] = edge_2_24; edge[2][25] = edge_2_25;
  edge[2][26] = edge_2_26; edge[2][27] = edge_2_27; edge[2][28] = edge_2_28; edge[2][29] = edge_2_29; edge[2][30] = edge_2_30;
  edge[2][31] = edge_2_31; edge[2][32] = edge_2_32; edge[2][33] = edge_2_33; edge[2][34] = edge_2_34; edge[2][35] = edge_2_35;
  edge[2][36] = edge_2_36; edge[2][37] = edge_2_37; edge[2][38] = edge_2_38; edge[2][39] = edge_2_39; edge[2][40] = edge_2_40;

  edge[3][1] = edge_3_1; edge[3][2] = edge_3_2; edge[3][3] = edge_3_3; edge[3][4] = edge_3_4; edge[3][5] = edge_3_5;
  edge[3][6] = edge_3_6; edge[3][7] = edge_3_7; edge[3][8] = edge_3_8; edge[3][9] = edge_3_9; edge[3][10] = edge_3_10;
  edge[3][11] = edge_3_11; edge[3][12] = edge_3_12; edge[3][13] = edge_3_13; edge[3][14] = edge_3_14; edge[3][15] = edge_3_15;
  edge[3][16] = edge_3_16; edge[3][17] = edge_3_17; edge[3][18] = edge_3_18; edge[3][19] = edge_3_19; edge[3][20] = edge_3_20;
  edge[3][21] = edge_3_21; edge[3][22] = edge_3_22; edge[3][23] = edge_3_23; edge[3][24] = edge_3_24; edge[3][25] = edge_3_25;
  edge[3][26] = edge_3_26; edge[3][27] = edge_3_27; edge[3][28] = edge_3_28; edge[3][29] = edge_3_29; edge[3][30] = edge_3_30;
  edge[3][31] = edge_3_31; edge[3][32] = edge_3_32; edge[3][33] = edge_3_33; edge[3][34] = edge_3_34; edge[3][35] = edge_3_35;
  edge[3][36] = edge_3_36; edge[3][37] = edge_3_37; edge[3][38] = edge_3_38; edge[3][39] = edge_3_39; edge[3][40] = edge_3_40;

  edge[4][1] = edge_4_1; edge[4][2] = edge_4_2; edge[4][3] = edge_4_3; edge[4][4] = edge_4_4; edge[4][5] = edge_4_5;
  edge[4][6] = edge_4_6; edge[4][7] = edge_4_7; edge[4][8] = edge_4_8; edge[4][9] = edge_4_9; edge[4][10] = edge_4_10;
  edge[4][11] = edge_4_11; edge[4][12] = edge_4_12; edge[4][13] = edge_4_13; edge[4][14] = edge_4_14; edge[4][15] = edge_4_15;
  edge[4][16] = edge_4_16; edge[4][17] = edge_4_17; edge[4][18] = edge_4_18; edge[4][19] = edge_4_19; edge[4][20] = edge_4_20;
  edge[4][21] = edge_4_21; edge[4][22] = edge_4_22; edge[4][23] = edge_4_23; edge[4][24] = edge_4_24; edge[4][25] = edge_4_25;
  edge[4][26] = edge_4_26; edge[4][27] = edge_4_27; edge[4][28] = edge_4_28; edge[4][29] = edge_4_29; edge[4][30] = edge_4_30;
  edge[4][31] = edge_4_31; edge[4][32] = edge_4_32; edge[4][33] = edge_4_33; edge[4][34] = edge_4_34; edge[4][35] = edge_4_35;
  edge[4][36] = edge_4_36; edge[4][37] = edge_4_37; edge[4][38] = edge_4_38; edge[4][39] = edge_4_39; edge[4][40] = edge_4_40;

  edge[5][1] = edge_5_1; edge[5][2] = edge_5_2; edge[5][3] = edge_5_3; edge[5][4] = edge_5_4; edge[5][5] = edge_5_5;
  edge[5][6] = edge_5_6; edge[5][7] = edge_5_7; edge[5][8] = edge_5_8; edge[5][9] = edge_5_9; edge[5][10] = edge_5_10;
  edge[5][11] = edge_5_11; edge[5][12] = edge_5_12; edge[5][13] = edge_5_13; edge[5][14] = edge_5_14; edge[5][15] = edge_5_15;
  edge[5][16] = edge_5_16; edge[5][17] = edge_5_17; edge[5][18] = edge_5_18; edge[5][19] = edge_5_19; edge[5][20] = edge_5_20;
  edge[5][21] = edge_5_21; edge[5][22] = edge_5_22; edge[5][23] = edge_5_23; edge[5][24] = edge_5_24; edge[5][25] = edge_5_25;
  edge[5][26] = edge_5_26; edge[5][27] = edge_5_27; edge[5][28] = edge_5_28; edge[5][29] = edge_5_29; edge[5][30] = edge_5_30;
  edge[5][31] = edge_5_31; edge[5][32] = edge_5_32; edge[5][33] = edge_5_33; edge[5][34] = edge_5_34; edge[5][35] = edge_5_35;
  edge[5][36] = edge_5_36; edge[5][37] = edge_5_37; edge[5][38] = edge_5_38; edge[5][39] = edge_5_39; edge[5][40] = edge_5_40;

  edge[6][1] = edge_6_1; edge[6][2] = edge_6_2; edge[6][3] = edge_6_3; edge[6][4] = edge_6_4; edge[6][5] = edge_6_5;
  edge[6][6] = edge_6_6; edge[6][7] = edge_6_7; edge[6][8] = edge_6_8; edge[6][9] = edge_6_9; edge[6][10] = edge_6_10;
  edge[6][11] = edge_6_11; edge[6][12] = edge_6_12; edge[6][13] = edge_6_13; edge[6][14] = edge_6_14; edge[6][15] = edge_6_15;
  edge[6][16] = edge_6_16; edge[6][17] = edge_6_17; edge[6][18] = edge_6_18; edge[6][19] = edge_6_19; edge[6][20] = edge_6_20;
  edge[6][21] = edge_6_21; edge[6][22] = edge_6_22; edge[6][23] = edge_6_23; edge[6][24] = edge_6_24; edge[6][25] = edge_6_25;
  edge[6][26] = edge_6_26; edge[6][27] = edge_6_27; edge[6][28] = edge_6_28; edge[6][29] = edge_6_29; edge[6][30] = edge_6_30;
  edge[6][31] = edge_6_31; edge[6][32] = edge_6_32; edge[6][33] = edge_6_33; edge[6][34] = edge_6_34; edge[6][35] = edge_6_35;
  edge[6][36] = edge_6_36; edge[6][37] = edge_6_37; edge[6][38] = edge_6_38; edge[6][39] = edge_6_39; edge[6][40] = edge_6_40;

  edge[7][1] = edge_7_1; edge[7][2] = edge_7_2; edge[7][3] = edge_7_3; edge[7][4] = edge_7_4; edge[7][5] = edge_7_5;
  edge[7][6] = edge_7_6; edge[7][7] = edge_7_7; edge[7][8] = edge_7_8; edge[7][9] = edge_7_9; edge[7][10] = edge_7_10;
  edge[7][11] = edge_7_11; edge[7][12] = edge_7_12; edge[7][13] = edge_7_13; edge[7][14] = edge_7_14; edge[7][15] = edge_7_15;
  edge[7][16] = edge_7_16; edge[7][17] = edge_7_17; edge[7][18] = edge_7_18; edge[7][19] = edge_7_19; edge[7][20] = edge_7_20;
  edge[7][21] = edge_7_21; edge[7][22] = edge_7_22; edge[7][23] = edge_7_23; edge[7][24] = edge_7_24; edge[7][25] = edge_7_25;
  edge[7][26] = edge_7_26; edge[7][27] = edge_7_27; edge[7][28] = edge_7_28; edge[7][29] = edge_7_29; edge[7][30] = edge_7_30;
  edge[7][31] = edge_7_31; edge[7][32] = edge_7_32; edge[7][33] = edge_7_33; edge[7][34] = edge_7_34; edge[7][35] = edge_7_35;
  edge[7][36] = edge_7_36; edge[7][37] = edge_7_37; edge[7][38] = edge_7_38; edge[7][39] = edge_7_39; edge[7][40] = edge_7_40;

  edge[8][1] = edge_8_1; edge[8][2] = edge_8_2; edge[8][3] = edge_8_3; edge[8][4] = edge_8_4; edge[8][5] = edge_8_5;
  edge[8][6] = edge_8_6; edge[8][7] = edge_8_7; edge[8][8] = edge_8_8; edge[8][9] = edge_8_9; edge[8][10] = edge_8_10;
  edge[8][11] = edge_8_11; edge[8][12] = edge_8_12; edge[8][13] = edge_8_13; edge[8][14] = edge_8_14; edge[8][15] = edge_8_15;
  edge[8][16] = edge_8_16; edge[8][17] = edge_8_17; edge[8][18] = edge_8_18; edge[8][19] = edge_8_19; edge[8][20] = edge_8_20;
  edge[8][21] = edge_8_21; edge[8][22] = edge_8_22; edge[8][23] = edge_8_23; edge[8][24] = edge_8_24; edge[8][25] = edge_8_25;
  edge[8][26] = edge_8_26; edge[8][27] = edge_8_27; edge[8][28] = edge_8_28; edge[8][29] = edge_8_29; edge[8][30] = edge_8_30;
  edge[8][31] = edge_8_31; edge[8][32] = edge_8_32; edge[8][33] = edge_8_33; edge[8][34] = edge_8_34; edge[8][35] = edge_8_35;
  edge[8][36] = edge_8_36; edge[8][37] = edge_8_37; edge[8][38] = edge_8_38; edge[8][39] = edge_8_39; edge[8][40] = edge_8_40;

  edge[9][1] = edge_9_1; edge[9][2] = edge_9_2; edge[9][3] = edge_9_3; edge[9][4] = edge_9_4; edge[9][5] = edge_9_5;
  edge[9][6] = edge_9_6; edge[9][7] = edge_9_7; edge[9][8] = edge_9_8; edge[9][9] = edge_9_9; edge[9][10] = edge_9_10;
  edge[9][11] = edge_9_11; edge[9][12] = edge_9_12; edge[9][13] = edge_9_13; edge[9][14] = edge_9_14; edge[9][15] = edge_9_15;
  edge[9][16] = edge_9_16; edge[9][17] = edge_9_17; edge[9][18] = edge_9_18; edge[9][19] = edge_9_19; edge[9][20] = edge_9_20;
  edge[9][21] = edge_9_21; edge[9][22] = edge_9_22; edge[9][23] = edge_9_23; edge[9][24] = edge_9_24; edge[9][25] = edge_9_25;
  edge[9][26] = edge_9_26; edge[9][27] = edge_9_27; edge[9][28] = edge_9_28; edge[9][29] = edge_9_29; edge[9][30] = edge_9_30;
  edge[9][31] = edge_9_31; edge[9][32] = edge_9_32; edge[9][33] = edge_9_33; edge[9][34] = edge_9_34; edge[9][35] = edge_9_35;
  edge[9][36] = edge_9_36; edge[9][37] = edge_9_37; edge[9][38] = edge_9_38; edge[9][39] = edge_9_39; edge[9][40] = edge_9_40;

  edge[10][1] = edge_10_1; edge[10][2] = edge_10_2; edge[10][3] = edge_10_3; edge[10][4] = edge_10_4; edge[10][5] = edge_10_5;
  edge[10][6] = edge_10_6; edge[10][7] = edge_10_7; edge[10][8] = edge_10_8; edge[10][9] = edge_10_9; edge[10][10] = edge_10_10;
  edge[10][11] = edge_10_11; edge[10][12] = edge_10_12; edge[10][13] = edge_10_13; edge[10][14] = edge_10_14; edge[10][15] = edge_10_15;
  edge[10][16] = edge_10_16; edge[10][17] = edge_10_17; edge[10][18] = edge_10_18; edge[10][19] = edge_10_19; edge[10][20] = edge_10_20;
  edge[10][21] = edge_10_21; edge[10][22] = edge_10_22; edge[10][23] = edge_10_23; edge[10][24] = edge_10_24; edge[10][25] = edge_10_25;
  edge[10][26] = edge_10_26; edge[10][27] = edge_10_27; edge[10][28] = edge_10_28; edge[10][29] = edge_10_29; edge[10][30] = edge_10_30;
  edge[10][31] = edge_10_31; edge[10][32] = edge_10_32; edge[10][33] = edge_10_33; edge[10][34] = edge_10_34; edge[10][35] = edge_10_35;
  edge[10][36] = edge_10_36; edge[10][37] = edge_10_37; edge[10][38] = edge_10_38; edge[10][39] = edge_10_39; edge[10][40] = edge_10_40;

  artist[1] = artist_1; artist[2] = artist_2; artist[3] = artist_3; artist[4] = artist_4; artist[5] = artist_5;
  artist[6] = artist_6; artist[7] = artist_7; artist[8] = artist_8; artist[9] = artist_9; artist[10] = artist_10;
  artist[11] = artist_11; artist[12] = artist_12; artist[13] = artist_13; artist[14] = artist_14; artist[15] = artist_15;
  artist[16] = artist_16; artist[17] = artist_17; artist[18] = artist_18; artist[19] = artist_19; artist[20] = artist_20;
  artist[21] = artist_21; artist[22] = artist_22; artist[23] = artist_23; artist[24] = artist_24; artist[25] = artist_25;
  artist[26] = artist_26; artist[27] = artist_27; artist[28] = artist_28; artist[29] = artist_29; artist[30] = artist_30;
  artist[31] = artist_31; artist[32] = artist_32; artist[33] = artist_33; artist[34] = artist_34; artist[35] = artist_35;
  artist[36] = artist_36; artist[37] = artist_37; artist[38] = artist_38; artist[39] = artist_39; artist[40] = artist_40;
  artist[41] = artist_41; artist[42] = artist_42; artist[43] = artist_43; artist[44] = artist_44; artist[45] = artist_45;
  artist[46] = artist_46; artist[47] = artist_47; artist[48] = artist_48; artist[49] = artist_49; artist[50] = artist_50;
  artist[51] = artist_51; artist[52] = artist_52; artist[53] = artist_53; artist[54] = artist_54; artist[55] = artist_55;
  artist[56] = artist_56; artist[57] = artist_57; artist[58] = artist_58; artist[59] = artist_59; artist[60] = artist_60;
  artist[61] = artist_61; artist[62] = artist_62; artist[63] = artist_63; artist[64] = artist_64; artist[65] = artist_65;
  artist[66] = artist_66; artist[67] = artist_67; artist[68] = artist_68; artist[69] = artist_69; artist[70] = artist_70;
  artist[71] = artist_71; artist[72] = artist_72; artist[73] = artist_73; artist[74] = artist_74; artist[75] = artist_75;
  artist[76] = artist_76; artist[77] = artist_77; artist[78] = artist_78; artist[79] = artist_79; artist[80] = artist_80;
  artist[81] = artist_81; artist[82] = artist_82; artist[83] = artist_83; artist[84] = artist_84; artist[85] = artist_85;
  artist[86] = artist_86; artist[87] = artist_87; artist[88] = artist_88; artist[89] = artist_89; artist[90] = artist_90;
  artist[91] = artist_91; artist[92] = artist_92; artist[93] = artist_93; artist[94] = artist_94; artist[95] = artist_95;
  artist[96] = artist_96; artist[97] = artist_97; artist[98] = artist_98; artist[99] = artist_99; artist[100] = artist_100;
end

// State machine
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    found <= 0;
    searching <= 0;
    current_node <= 0;
    next_node <= 0;
    depth <= 0;
    start_node <= 0;
    edge_index <= 0;
    artist_mask <= 0;
    for (i = 0; i < 9; i = i + 1) begin
      path[i] <= 0;
    end
  end else begin
    case (state)
      IDLE: begin
        found <= 0;
        searching <= 0;
        if (start) begin
          state <= INIT_START;
          searching <= 1;
        end
      end

      INIT_START: begin
        start_node <= start_node + 1;
        if (start_node > n) begin
          state <= FAIL;
        end else begin
          current_node <= start_node;
          depth <= 1;
          path[0] <= start_node;
          artist_mask <= 1 << artist[start_node];
          edge_index <= 0;
          state <= SEARCH;
        end
      end

      SEARCH: begin
        edge_index <= edge_index + 1;
        if (edge_index > num_edges[current_node]) begin
          state <= INIT_START;
        end else begin
          next_node <= edge[current_node][edge_index];
          state <= CHECK_EDGE;
        end
      end

      CHECK_EDGE: begin
        if (artist_mask & (1 << artist[next_node])) begin
          state <= SEARCH;
        end else begin
          depth <= depth + 1;
          path[depth - 1] <= next_node;
          artist_mask <= artist_mask | (1 << artist[next_node]);
          if (depth == 9) begin
            state <= FOUND;
          end else begin
            current_node <= next_node;
            edge_index <= 0;
            state <= SEARCH;
          end
        end
      end

      FOUND: begin
        found <= 1;
        searching <= 0;
        song_1 <= path[0];
        song_2 <= path[1];
        song_3 <= path[2];
        song_4 <= path[3];
        song_5 <= path[4];
        song_6 <= path[5];
        song_7 <= path[6];
        song_8 <= path[7];
        song_9 <= path[8];
        state <= IDLE;
      end

      FAIL: begin
        found <= 0;
        searching <= 0;
        state <= IDLE;
      end

      default: state <= IDLE;
    endcase
  end
end

endmodule