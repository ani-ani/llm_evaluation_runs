module top (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [2:0] n,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg done
);

    // Maximum constants
    parameter MAX_SIZE = 8;
    parameter MAX_N = 5;
    
    // Internal state registers
    reg [7:0] sorted [0:MAX_SIZE-1];
    reg [3:0] idx;
    reg [3:0] comp_idx;
    reg [2:0] output_idx;
    reg processing;
    reg outputting;
    
    // Combinational comparison result
    wire swap;
    assign swap = (sorted[comp_idx] < sorted[comp_idx+1]);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            idx <= 4'd0;
            comp_idx <= 4'd0;
            output_idx <= 3'd0;
            processing <= 1'b0;
            outputting <= 1'b0;
            done <= 1'b0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            // Initialize sorted array to zeros
            sorted[0] <= 8'd0;
            sorted[1] <= 8'd0;
            sorted[2] <= 8'd0;
            sorted[3] <= 8'd0;
            sorted[4] <= 8'd0;
            sorted[5] <= 8'd0;
            sorted[6] <= 8'd0;
            sorted[7] <= 8'd0;
        end else if (start && !processing && !outputting) begin
            // Load input array and start processing
            sorted[0] <= arr_0;
            sorted[1] <= arr_1;
            sorted[2] <= arr_2;
            sorted[3] <= arr_3;
            sorted[4] <= arr_4;
            sorted[5] <= arr_5;
            sorted[6] <= arr_6;
            sorted[7] <= arr_7;
            idx <= 4'd0;
            comp_idx <= 4'd0;
            processing <= 1'b1;
            outputting <= 1'b0;
            done <= 1'b0;
        end else if (processing) begin
            // Bubble sort: bubble largest elements to the end
            if (comp_idx < 4'd7) begin
                if (swap) begin
                    // Swap elements
                    sorted[comp_idx] <= sorted[comp_idx+1];
                    sorted[comp_idx+1] <= sorted[comp_idx];
                end
                comp_idx <= comp_idx + 1'b1;
            end else begin
                // End of one pass
                comp_idx <= 4'd0;
                if (idx < 4'd7) begin
                    idx <= idx + 1'b1;
                end else begin
                    // Sorting complete, prepare for output
                    processing <= 1'b0;
                    outputting <= 1'b1;
                    output_idx <= 3'd0;
                end
            end
        end else if (outputting) begin
            // Output the n largest values (from the end of sorted array)
            if (output_idx < n && output_idx < MAX_N) begin
                case (output_idx)
                    3'd0: result_0 <= sorted[MAX_SIZE - 1];
                    3'd1: result_1 <= sorted[MAX_SIZE - 2];
                    3'd2: result_2 <= sorted[MAX_SIZE - 3];
                    3'd3: result_3 <= sorted[MAX_SIZE - 4];
                    3'd4: result_4 <= sorted[MAX_SIZE - 5];
                    default: begin
                        result_0 <= result_0;
                        result_1 <= result_1;
                        result_2 <= result_2;
                        result_3 <= result_3;
                        result_4 <= result_4;
                    end
                endcase
                output_idx <= output_idx + 1'b1;
            end else begin
                // Output complete
                done <= 1'b1;
                outputting <= 1'b0;
            end
        end else begin
            done <= 1'b0;
        end
    end

endmodule