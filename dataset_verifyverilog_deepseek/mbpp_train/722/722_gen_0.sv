module student_filter(
  input [7:0] student0_height,
  input [7:0] student0_weight,
  input [7:0] student1_height,
  input [7:0] student1_weight,
  input [7:0] student2_height,
  input [7:0] student2_weight,
  input [7:0] student3_height,
  input [7:0] student3_weight,
  input [7:0] min_height,
  input [7:0] min_weight,
  output [3:0] passed_students
);

  assign passed_students = {
    (student3_height >= min_height) && (student3_weight >= min_weight),
    (student2_height >= min_height) && (student2_weight >= min_weight),
    (student1_height >= min_height) && (student1_weight >= min_weight),
    (student0_height >= min_height) && (student0_weight >= min_weight)
  };

endmodule