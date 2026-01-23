module student_filter (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [15:0] min_height,
    input [15:0] min_weight,
    input [2:0] student_count,
    input [63:0] student0_name,
    input [31:0] student0_height,
    input [31:0] student0_weight,
    input student0_valid,
    input [63:0] student1_name,
    input [31:0] student1_height,
    input [31:0] student1_weight,
    input student1_valid,
    input [63:0] student2_name,
    input [31:0] student2_height,
    input [31:0] student2_weight,
    input student2_valid,
    input [63:0] student3_name,
    input [31:0] student3_height,
    input [31:0] student3_weight,
    input student3_valid,
    output reg [2:0] result_count,
    output reg [63:0] result_name_0,
    output reg [63:0] result_name_1,
    output reg [63:0] result_name_2,
    output reg [63:0] result_name_3,
    output reg done
);
localparam IDLE = 3'd0,
        LOAD_0 =1,
        LOAD_1 =2,
        LOAD_2 =3,
        LOAD_3 =4,
        DONE =5;
reg [2:0] state;
reg [2:0] result_count;
reg [63:0] result_name_0, result_name_1, result_name_2, result_name_3;
reg done;
reg done_counter;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result_count <=3'd0;
        result_name_0 <=64'd0;
        result_name_1 <=64'd0;
        result_name_2 <=64'd0;
        result_name_3 <=64'd0;
        done <=1'b0;
        done_counter <=1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD_0;
                end
                done <=1'b0;
                done_counter <=1'b0;
            end
            LOAD_0: begin
                if (student_count > 0 && student0_valid) begin
                    if (student0_height >= min_height && student0_weight >= min_weight) begin
                        if (result_count < 4) begin
                            if (result_count ==0) begin
                                result_name_0 <= student0_name;
                            end else if (result_count ==1) begin
                                result_name_1 <= student0_name;
                            end else if (result_count ==2) begin
                                result_name_2 <= student0_name;
                            end else if (result_count ==3) begin
                                result_name_3 <= student0_name;
                            end
                            result_count <= result_count +1;
                        end
                    end
                end
                state <= LOAD_1;
                done_counter <=1'b0;
            end
            LOAD_1: begin
                if (student_count >1 && student1_valid) begin
                    if (student1_height >= min_height && student1_weight >= min_weight) begin
                        if (result_count <4) begin
                            if (result_count ==0) begin
                                result_name_0 <= student1_name;
                            end else if (result_count ==1) begin
                                result_name_1 <= student1_name;
                            end else if (result_count ==2) begin
                                result_name_2 <= student1_name;
                            end else if (result_count ==3) begin
                                result_name_3 <= student1_name;
                            end
                            result_count <= result_count +1;
                        end
                    end
                end
                state <= LOAD_2;
                done_counter <=1'b0;
            end
            LOAD_2: begin
                if (student_count >2 && student2_valid) begin
                    if (student2_height >= min_height && student2_weight >= min_weight) begin
                        if (result_count <4) begin
                            if (result_count ==0) begin
                                result_name_0 <= student2_name;
                            end else if (result_count ==1) begin
                                result_name_1 <= student2_name;
                            end else if (result_count ==2) begin
                                result_name_2 <= student2_name;
                            end else if (result_count ==3) begin
                                result_name_3 <= student2_name;
                            end
                            result_count <= result_count +1;
                        end
                    end
                end
                state <= LOAD_3;
                done_counter <=1'b0;
            end
            LOAD_3: begin
                if (student_count >3 && student3_valid) begin
                    if (student3_height >= min_height && student3_weight >= min_weight) begin
                        if (result_count <4) begin
                            if (result_count ==0) begin
                                result_name_0 <= student3_name;
                            end else if (result_count ==1) begin
                                result_name_1 <= student3_name;
                            end else if (result_count ==2) begin
                                result_name_2 <= student3_name;
                            end else if (result_count ==3) begin
                                result_name_3 <= student3_name;
                            end
                            result_count <= result_count +1;
                        end
                    end
                end
                state <= DONE;
                done_counter <=1'b1;
            end
            DONE: begin
                if (done_counter ==1'b0) begin
                    done <=1'b1;
                end else begin
                    done <=1'b0;
                    done_counter <=1'b0;
                end
            end
        endcase
    end
endmodule