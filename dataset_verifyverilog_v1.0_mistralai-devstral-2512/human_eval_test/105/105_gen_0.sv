module digit_to_name_converter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [63:0] result [0:15],
    output reg done,
    output reg [3:0] result_len
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FILTER = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] REVERSE = 3'd3;
    localparam [2:0] MAP = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Control signals
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Filtered array (valid digits 1-9)
    reg signed [7:0] filtered_arr [0:15];
    reg [3:0] filtered_len;

    // Sorted array
    reg signed [7:0] sorted_arr [0:15];

    // Reversed array
    reg signed [7:0] reversed_arr [0:15];

    // Sorting network control
    reg [3:0] sort_stage;
    localparam [3:0] MAX_SORT_STAGES = 4'd16;

    // LUT for digit to name mapping
    localparam [63:0] ONE   = 64'h4F6E650000000000;
    localparam [63:0] TWO   = 64'h54776F0000000000;
    localparam [63:0] THREE = 64'h5468726565000000;
    localparam [63:0] FOUR  = 64'h466F757200000000;
    localparam [63:0] FIVE  = 64'h4669766500000000;
    localparam [63:0] SIX   = 64'h5369780000000000;
    localparam [63:0] SEVEN = 64'h536576656E000000;
    localparam [63:0] EIGHT = 64'h4569676874000000;
    localparam [63:0] NINE  = 64'h4E696E6500000000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_len <= 4'd0;
            
            // Initialize all output registers
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 64'd0;
            end
            
            // Initialize internal arrays
            for (i = 0; i < 16; i = i + 1) begin
                filtered_arr[i] <= 8'd0;
                sorted_arr[i] <= 8'd0;
                reversed_arr[i] <= 8'd0;
            end
            filtered_len <= 4'd0;
            sort_stage <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FILTER;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FILTER: begin
                    // Filter valid digits (1-9)
                    integer i, j;
                    j = 0;
                    for (i = 0; i < len; i = i + 1) begin
                        if (arr[i] >= 8'd1 && arr[i] <= 8'd9) begin
                            filtered_arr[j] <= arr[i];
                            j = j + 1;
                        end
                    end
                    filtered_len <= j;
                    next_state <= SORT;
                end

                SORT: begin
                    // Odd-even transposition sort
                    integer i;
                    
                    // Even stage
                    if (sort_stage[0] == 1'b0) begin
                        for (i = 0; i < 15; i = i + 2) begin
                            if (i+1 < filtered_len && filtered_arr[i] > filtered_arr[i+1]) begin
                                // Swap
                                sorted_arr[i] <= filtered_arr[i+1];
                                sorted_arr[i+1] <= filtered_arr[i];
                            end else begin
                                sorted_arr[i] <= filtered_arr[i];
                                sorted_arr[i+1] <= filtered_arr[i+1];
                            end
                        end
                        // Copy unchanged elements for odd positions
                        if (filtered_len > 1 && filtered_len % 2 == 1'b1) begin
                            sorted_arr[filtered_len-1] <= filtered_arr[filtered_len-1];
                        end
                    end
                    // Odd stage
                    else begin
                        for (i = 1; i < 15; i = i + 2) begin
                            if (i+1 < filtered_len && filtered_arr[i] > filtered_arr[i+1]) begin
                                // Swap
                                sorted_arr[i] <= filtered_arr[i+1];
                                sorted_arr[i+1] <= filtered_arr[i];
                            end else begin
                                sorted_arr[i] <= filtered_arr[i];
                                sorted_arr[i+1] <= filtered_arr[i+1];
                            end
                        end
                        // Copy unchanged elements for even positions
                        if (filtered_len > 0) begin
                            sorted_arr[0] <= filtered_arr[0];
                        end
                        if (filtered_len > 1 && filtered_len % 2 == 1'b0) begin
                            sorted_arr[filtered_len-1] <= filtered_arr[filtered_len-1];
                        end
                    end
                    
                    // Update filtered_arr for next stage
                    for (i = 0; i < 16; i = i + 1) begin
                        filtered_arr[i] <= sorted_arr[i];
                    end
                    
                    // Increment stage counter
                    if (sort_stage == MAX_SORT_STAGES - 1) begin
                        sort_stage <= 4'd0;
                        next_state <= REVERSE;
                    end else begin
                        sort_stage <= sort_stage + 4'd1;
                        next_state <= SORT;
                    end
                end

                REVERSE: begin
                    // Reverse the sorted array
                    integer i;
                    for (i = 0; i < filtered_len; i = i + 1) begin
                        reversed_arr[i] <= sorted_arr[filtered_len - 1 - i];
                    end
                    next_state <= MAP;
                end

                MAP: begin
                    // Map digits to names
                    integer i;
                    for (i = 0; i < filtered_len; i = i + 1) begin
                        case (reversed_arr[i])
                            8'd1: result[i] <= ONE;
                            8'd2: result[i] <= TWO;
                            8'd3: result[i] <= THREE;
                            8'd4: result[i] <= FOUR;
                            8'd5: result[i] <= FIVE;
                            8'd6: result[i] <= SIX;
                            8'd7: result[i] <= SEVEN;
                            8'd8: result[i] <= EIGHT;
                            8'd9: result[i] <= NINE;
                            default: result[i] <= 64'd0;
                        endcase
                    end
                    result_len <= filtered_len;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter for timeout
            if (state != IDLE && state != DONE_STATE) begin
                if (cycle_count == MAX_CYCLES) begin
                    next_state <= IDLE;
                    cycle_count <= 8'd0;
                end else begin
                    cycle_count <= cycle_count + 8'd1;
                end
            end
        end
    end

endmodule