module sort_even(
    input wire clk,
    input wire rst_n,
    input wire start,
    input signed [7:0] arr_0,
    input signed [7:0] arr_1,
    input signed [7:0] arr_2,
    input signed [7:0] arr_3,
    input signed [7:0] arr_4,
    input signed [7:0] arr_5,
    input signed [7:0] arr_6,
    input signed [7:0] arr_7,
    input signed [7:0] arr_8,
    input signed [7:0] arr_9,
    input signed [7:0] arr_10,
    input signed [7:0] arr_11,
    input signed [7:0] arr_12,
    input signed [7:0] arr_13,
    input signed [7:0] arr_14,
    input signed [7:0] arr_15,
    input wire [3:0] len,
    output reg signed [7:0] result_0,
    output reg signed [7:0] result_1,
    output reg signed [7:0] result_2,
    output reg signed [7:0] result_3,
    output reg signed [7:0] result_4,
    output reg signed [7:0] result_5,
    output reg signed [7:0] result_6,
    output reg signed [7:0] result_7,
    output reg signed [7:0] result_8,
    output reg signed [7:0] result_9,
    output reg signed [7:0] result_10,
    output reg signed [7:0] result_11,
    output reg signed [7:0] result_12,
    output reg signed [7:0] result_13,
    output reg signed [7:0] result_14,
    output reg signed [7:0] result_15,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] EXTRACT = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] ASSIGN  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Temporary storage for even indices
    reg signed [7:0] even_temp [0:7];
    reg [3:0] even_count;

    // Bubble sort variables
    reg [3:0] i, j;
    reg signed [7:0] temp_val;

    // Cycle counter for timeout prevention
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            even_count <= 4'd0;
            
            // Initialize all result registers
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            result_8 <= 8'd0;
            result_9 <= 8'd0;
            result_10 <= 8'd0;
            result_11 <= 8'd0;
            result_12 <= 8'd0;
            result_13 <= 8'd0;
            result_14 <= 8'd0;
            result_15 <= 8'd0;
            
            // Initialize even_temp array
            even_temp[0] <= 8'd0;
            even_temp[1] <= 8'd0;
            even_temp[2] <= 8'd0;
            even_temp[3] <= 8'd0;
            even_temp[4] <= 8'd0;
            even_temp[5] <= 8'd0;
            even_temp[6] <= 8'd0;
            even_temp[7] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= EXTRACT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                EXTRACT: begin
                    // Extract even indices from input array
                    even_count <= (len + 4'd1) / 4'd2;  // Number of even indices
                    
                    // Store even indices in temporary array
                    even_temp[0] <= arr_0;
                    even_temp[1] <= arr_2;
                    even_temp[2] <= arr_4;
                    even_temp[3] <= arr_6;
                    even_temp[4] <= arr_8;
                    even_temp[5] <= arr_10;
                    even_temp[6] <= arr_12;
                    even_temp[7] <= arr_14;
                    
                    // Initialize bubble sort counters
                    i <= 4'd0;
                    j <= 4'd0;
                    next_state <= SORT;
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort implementation
                    if (j < even_count - 4'd1) begin
                        if (even_temp[j] > even_temp[j + 4'd1]) begin
                            // Swap elements
                            temp_val <= even_temp[j];
                            even_temp[j] <= even_temp[j + 4'd1];
                            even_temp[j + 4'd1] <= temp_val;
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        if (i < even_count - 4'd2) begin
                            i <= i + 4'd1;
                        end else begin
                            next_state <= ASSIGN;
                        end
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                ASSIGN: begin
                    // Copy odd indices directly from input
                    result_1 <= arr_1;
                    result_3 <= arr_3;
                    result_5 <= arr_5;
                    result_7 <= arr_7;
                    result_9 <= arr_9;
                    result_11 <= arr_11;
                    result_13 <= arr_13;
                    result_15 <= arr_15;
                    
                    // Place sorted even indices back
                    result_0 <= even_temp[0];
                    result_2 <= even_temp[1];
                    result_4 <= even_temp[2];
                    result_6 <= even_temp[3];
                    result_8 <= even_temp[4];
                    result_10 <= even_temp[5];
                    result_12 <= even_temp[6];
                    result_14 <= even_temp[7];
                    
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
        end
    end

endmodule