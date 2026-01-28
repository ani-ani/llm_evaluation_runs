module Sorter(
    input clk,
    input rst_n,
    input start,
    input [3:0] in_name [0:7],
    input [7:0] in_marks [0:7],
    input valid_in [0:7],
    output reg [3:0] out_name [0:7],
    output reg [7:0] out_marks [0:7],
    output reg out_valid [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORT = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers for sorting
    reg [3:0] name_reg [0:7];
    reg [7:0] marks_reg [0:7];
    reg valid_reg [0:7];

    // Bubble sort network - 28 comparators for 8 elements
    integer i, j;
    reg [3:0] temp_name;
    reg [7:0] temp_marks;
    reg temp_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all outputs to 0
            for (i = 0; i < 8; i = i + 1) begin
                out_name[i] <= 4'd0;
                out_marks[i] <= 8'd0;
                out_valid[i] <= 1'b0;
                name_reg[i] <= 4'd0;
                marks_reg[i] <= 8'd0;
                valid_reg[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    // Load input data when start is asserted
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            name_reg[i] <= in_name[i];
                            marks_reg[i] <= in_marks[i];
                            valid_reg[i] <= valid_in[i];
                        end
                        state <= SORT;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort implementation
                    // Outer loop - 7 passes for 8 elements
                    for (i = 0; i < 7; i = i + 1) begin
                        // Inner loop - compare adjacent elements
                        for (j = 0; j < 7 - i; j = j + 1) begin
                            // Only compare if both are valid
                            if (valid_reg[j] && valid_reg[j + 1]) begin
                                // Compare marks and swap if needed
                                if (marks_reg[j] > marks_reg[j + 1]) begin
                                    // Swap names
                                    temp_name = name_reg[j];
                                    name_reg[j] = name_reg[j + 1];
                                    name_reg[j + 1] = temp_name;
                                    
                                    // Swap marks
                                    temp_marks = marks_reg[j];
                                    marks_reg[j] = marks_reg[j + 1];
                                    marks_reg[j + 1] = temp_marks;
                                    
                                    // Valid bits stay with their positions
                                end
                            end
                            // If one is invalid, no swap needed
                        end
                    end
                    
                    // Check if sorting is complete
                    if (cycle_count >= MAX_CYCLES - 1) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Copy sorted data to outputs
                    for (i = 0; i < 8; i = i + 1) begin
                        out_name[i] <= name_reg[i];
                        out_marks[i] <= marks_reg[i];
                        out_valid[i] <= valid_reg[i];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule