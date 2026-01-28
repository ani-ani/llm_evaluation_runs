module flatten_2d_array(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr0 [0:7],
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    input wire [7:0] arr3 [0:7],
    input wire [7:0] arr4 [0:7],
    input wire [7:0] arr5 [0:7],
    input wire [7:0] arr6 [0:7],
    input wire [7:0] arr7 [0:7],
    input wire [7:0] len,
    input wire [3:0] valid_len [0:7],
    output reg [511:0] result,
    output reg done,
    output reg [5:0] count
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [5:0] result_index;
    reg [2:0] subarray_index;
    reg [2:0] element_index;
    reg [5:0] total_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_index <= 6'd0;
            subarray_index <= 3'd0;
            element_index <= 3'd0;
            total_count <= 6'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            count <= 6'd0;
            // Initialize result array
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                result[(i*8)+7:(i*8)] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end
            end
            PROCESS: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else if (subarray_index == 3'd7 && element_index == valid_len[7]) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized above
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    result_index <= 6'd0;
                    subarray_index <= 3'd0;
                    element_index <= 3'd0;
                    total_count <= 6'd0;
                end
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current subarray has valid data
                    if (len[subarray_index] && element_index < valid_len[subarray_index]) begin
                        // Write to result array
                        case (subarray_index)
                            3'd0: result[(result_index*8)+7:(result_index*8)] <= arr0[element_index];
                            3'd1: result[(result_index*8)+7:(result_index*8)] <= arr1[element_index];
                            3'd2: result[(result_index*8)+7:(result_index*8)] <= arr2[element_index];
                            3'd3: result[(result_index*8)+7:(result_index*8)] <= arr3[element_index];
                            3'd4: result[(result_index*8)+7:(result_index*8)] <= arr4[element_index];
                            3'd5: result[(result_index*8)+7:(result_index*8)] <= arr5[element_index];
                            3'd6: result[(result_index*8)+7:(result_index*8)] <= arr6[element_index];
                            3'd7: result[(result_index*8)+7:(result_index*8)] <= arr7[element_index];
                        endcase
                        
                        // Update counters
                        result_index <= result_index + 6'd1;
                        total_count <= total_count + 6'd1;
                        element_index <= element_index + 3'd1;
                        
                        // Check if we've processed all elements in this subarray
                        if (element_index == valid_len[subarray_index]) begin
                            element_index <= 3'd0;
                            subarray_index <= subarray_index + 3'd1;
                        end
                    end else begin
                        // Skip to next subarray
                        element_index <= 3'd0;
                        subarray_index <= subarray_index + 3'd1;
                    end
                    
                    // Check completion condition
                    if (subarray_index == 3'd7 && element_index == valid_len[7]) begin
                        next_state = DONE_STATE;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    count <= total_count;
                end
                default: begin
                    done <= 1'b0;
                    count <= 6'd0;
                end
            endcase
        end
    end

endmodule