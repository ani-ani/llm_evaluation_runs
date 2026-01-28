module max_density_subsequence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,
    input wire [3:0] L,
    input wire [15:0] str,
    output reg [4:0] start_index,
    output reg [4:0] length,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] LOOP_I  = 3'd2;
    localparam [2:0] LOOP_J  = 3'd3;
    localparam [2:0] UPDATE  = 3'd4;
    localparam [2:0] DONE    = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [4:0] count;
    reg [4:0] best_start;
    reg [4:0] best_len;
    reg [4:0] best_ones;
    reg [4:0] current_len;
    reg [7:0] current_ones;
    reg [7:0] best_ones_calc;
    reg [4:0] calc_len;

    // Combinational multiplication result (for density comparison)
    reg [8:0] left_mult;
    reg [8:0] right_mult;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            start_index <= 5'd0;
            length <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            count <= 5'd0;
            best_start <= 5'd0;
            best_len <= 5'd0;
            best_ones <= 5'd0;
            best_ones_calc <= 8'd0;
            calc_len <= 5'd0;
            current_len <= 5'd0;
            current_ones <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize search
                    i <= 4'd0;
                    j <= 4'd0;
                    count <= 5'd0;
                    best_start <= 5'd0;
                    best_len <= 5'd0;
                    best_ones <= 5'd0;
                    best_ones_calc <= 8'd0;
                    calc_len <= 5'd0;
                    current_len <= 5'd0;
                    current_ones <= 8'd0;
                    state <= LOOP_I;
                end

                LOOP_I: begin
                    if (i >= L) begin
                        state <= DONE;
                    end else begin
                        j <= i;
                        count <= 5'd0;
                        state <= LOOP_J;
                    end
                end

                LOOP_J: begin
                    // Add current bit to count
                    count <= count + {4'd0, str[j]};
                    // Calculate length
                    current_len <= j - i + 1;  // Will be adjusted in UPDATE
                    current_ones <= count + {4'd0, str[j]};
                    
                    // Check if we have minimum length
                    if (j - i + 1 >= k) begin
                        state <= UPDATE;
                    end else begin
                        // Continue incrementing j
                        if (j + 1 < L) begin
                            j <= j + 1;
                            state <= LOOP_J;
                        end else begin
                            i <= i + 1;
                            state <= LOOP_I;
                        end
                    end
                end

                UPDATE: begin
                    // Current subsequence has minimum length
                    // Calculate: current_len = j - i + 1, current_ones = count
                    current_len <= j - i + 1;
                    current_ones <= count;
                    
                    // Update best if needed
                    if (best_len == 5'd0) begin
                        // First valid subsequence
                        best_start <= i;
                        best_len <= j - i + 1;
                        best_ones <= count;
                    end else begin
                        // Compare densities: count/(j-i+1) > best_ones/best_len
                        // Cross multiply: count * best_len > best_ones * (j-i+1)
                        left_mult <= count * best_len;
                        right_mult <= best_ones * (j - i + 1);
                        
                        if (count * best_len > best_ones * (j - i + 1)) begin
                            best_start <= i;
                            best_len <= j - i + 1;
                            best_ones <= count;
                        end
                    end
                    
                    // Continue to next j
                    if (j + 1 < L) begin
                        j <= j + 1;
                        state <= LOOP_J;
                    end else begin
                        i <= i + 1;
                        state <= LOOP_I;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    start_index <= best_start + 5'd1;  // Convert to 1-based
                    length <= best_len;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule