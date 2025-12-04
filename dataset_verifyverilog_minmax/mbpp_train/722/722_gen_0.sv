module student_filter (
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
  output reg [3:0] passed_students
);
  integer i;
  always @(*) begin
    passed_students = 4'b0;
    for (i = 0; i < 4; i = i + 1) begin
      case (i)
        0: passed_students[0] = (student0_height >= min_height) && (student0_weight >= min_weight);
        1: passed_students[1] = (student1_height >= min_height) && (student1_weight >= min_weight);
        2: passed_students[2] = (student2_height >= min_height) && (student2_weight >= min_weight);
        3: passed_students[3] = (student3_height >= min_height) && (student3_weight >= min_weight);
      endcase
    end
  end
endmodule
