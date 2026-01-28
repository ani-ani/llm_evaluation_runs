module find_missing_number(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] COMPARE  = 3'd1;
    localparam [2:0] UPDATE   = 3'd2;
    localparam [2:0] DONE     = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [7:0] low;
    reg [7:0] high;
    reg [7:0] mid;
    reg [7:0] count;
    reg [7:0] arr_mid_val;
    
    // Array access with registered values
    reg [7:0] arr_reg [0:7];
    
    // Counter to prevent infinite loops
    localparam [7:0] MAX_ITER = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            low <= 8'd0;
            high <= 8'd7;
            mid <= 8'd0;
            count <= 8'd0;
            arr_mid_val <= 8'd0;
            // Initialize array registers
            arr_reg[0] <= 8'd0;
            arr_reg[1] <= 8'd0;
            arr_reg[2] <= 8'd0;
            arr_reg[3] <= 8'd0;
            arr_reg[4] <= 8'd0;
            arr_reg[5] <= 8'd0;
            arr_reg[6] <= 8'd0;
            arr_reg[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    low <= 8'd0;
                    high <= 8'd7;
                    mid <= 8'd0;
                    count <= 8'd0;
                    if (start) begin
                        // Capture input array
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Binary search condition check
                    if (low <= high && count < MAX_ITER) begin
                        mid <= (low + high) >> 1;
                        state <= UPDATE;
                    end else begin
                        // Loop ended, first missing number is low
                        result <= low;
                        state <= DONE;
                    end
                end

                UPDATE: begin
                    // Increment iteration counter
                    count <= count + 8'd1;
                    
                    // Get array value at mid position
                    case (mid)
                        8'd0: arr_mid_val <= arr_reg[0];
                        8'd1: arr_mid_val <= arr_reg[1];
                        8'd2: arr_mid_val <= arr_reg[2];
                        8'd3: arr_mid_val <= arr_reg[3];
                        8'd4: arr_mid_val <= arr_reg[4];
                        8'd5: arr_mid_val <= arr_reg[5];
                        8'd6: arr_mid_val <= arr_reg[6];
                        8'd7: arr_mid_val <= arr_reg[7];
                        default: arr_mid_val <= 8'd0;
                    endcase
                    
                    // Decision: if arr[mid] == mid, search right; else search left
                    if (arr_mid_val == mid) begin
                        low <= mid + 8'd1;
                    end else begin
                        if (mid > 8'd0) begin
                            high <= mid - 8'd1;
                        end else begin
                            high <= 8'd0;
                        end
                    end
                    
                    state <= COMPARE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule