module TypeFilter(
    input clk,
    input rst_n,
    input start,
    input [15:0] arr [0:7],
    output reg [255:0] result,
    output reg [3:0] count,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FILTERING = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] index;          // Iteration index for 8 elements
    reg [3:0] out_pos;        // Output position counter (0-8)
    reg [15:0] temp_result [0:7]; // Temporary storage for filtered values
    reg [3:0] temp_count;
    reg [7:0] cycle_count;    // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd20;
    
    // Combinational wire for type check
    wire is_integer;
    assign is_integer = (arr[index][15] == 1'b0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 3'd0;
            out_pos <= 4'd0;
            count <= 4'd0;
            done <= 1'b0;
            result <= 256'd0;
            temp_count <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize temp_result array
            temp_result[0] <= 16'd0;
            temp_result[1] <= 16'd0;
            temp_result[2] <= 16'd0;
            temp_result[3] <= 16'd0;
            temp_result[4] <= 16'd0;
            temp_result[5] <= 16'd0;
            temp_result[6] <= 16'd0;
            temp_result[7] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    out_pos <= 4'd0;
                    temp_count <= 4'd0;
                    cycle_count <= 8'd0;
                    
                    // Clear temp_result array
                    temp_result[0] <= 16'd0;
                    temp_result[1] <= 16'd0;
                    temp_result[2] <= 16'd0;
                    temp_result[3] <= 16'd0;
                    temp_result[4] <= 16'd0;
                    temp_result[5] <= 16'd0;
                    temp_result[6] <= 16'd0;
                    temp_result[7] <= 16'd0;
                    
                    if (start) begin
                        state <= FILTERING;
                    end
                end
                
                FILTERING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current element if type is integer
                    if (is_integer && (out_pos < 4'd8)) begin
                        case (out_pos)
                            4'd0: temp_result[0] <= arr[index];
                            4'd1: temp_result[1] <= arr[index];
                            4'd2: temp_result[2] <= arr[index];
                            4'd3: temp_result[3] <= arr[index];
                            4'd4: temp_result[4] <= arr[index];
                            4'd5: temp_result[5] <= arr[index];
                            4'd6: temp_result[6] <= arr[index];
                            4'd7: temp_result[7] <= arr[index];
                        endcase
                        temp_count <= temp_count + 4'd1;
                        out_pos <= out_pos + 4'd1;
                    end
                    
                    // Move to next element
                    index <= index + 3'd1;
                    
                    // Check if we've processed all 8 elements or hit timeout
                    if (index == 3'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Pack results into 256-bit output
                    result[15:0]   <= temp_result[0];
                    result[31:16]  <= temp_result[1];
                    result[47:32]  <= temp_result[2];
                    result[63:48]  <= temp_result[3];
                    result[79:64]  <= temp_result[4];
                    result[95:80]  <= temp_result[5];
                    result[111:96] <= temp_result[6];
                    result[127:112] <= temp_result[7];
                    // Remaining bits remain zero
                    
                    count <= temp_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule