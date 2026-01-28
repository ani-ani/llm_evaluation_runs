module ComputeAverage(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] m,
    output reg [7:0] result,
    output reg valid,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] SUMMING   = 3'd2;
    localparam [2:0] CALC      = 3'd3;
    localparam [2:0] DONE      = 3'd4;
    localparam [2:0] ERROR_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] current_n;
    reg [15:0] sum_reg;
    reg [8:0] count_reg;  // 9 bits for up to 256
    reg [8:0] iteration_counter;
    reg [15:0] numerator;
    reg [7:0] denominator;
    reg [15:0] calc_result;
    reg calc_done;

    // Division control signals
    reg div_start;
    reg div_done;
    reg [15:0] div_num;
    reg [7:0] div_den;
    reg [15:0] div_result;
    reg [7:0] div_count;
    reg div_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            valid <= 1'b0;
            error <= 1'b0;
            current_n <= 8'd0;
            sum_reg <= 16'd0;
            count_reg <= 9'd0;
            iteration_counter <= 9'd0;
            numerator <= 16'd0;
            denominator <= 8'd0;
            calc_result <= 16'd0;
            calc_done <= 1'b0;
            div_start <= 1'b0;
            div_busy <= 1'b0;
            div_done <= 1'b0;
            div_num <= 16'd0;
            div_den <= 8'd0;
            div_count <= 8'd0;
        end else begin
            // Default outputs
            valid <= 1'b0;
            error <= 1'b0;
            div_start <= 1'b0;
            div_done <= 1'b0;
            calc_done <= 1'b0;

            case (state)
                IDLE: begin
                    result <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                        current_n <= n;
                        // Clamp m and n to 255 if larger
                        // (though spec says inputs <= 255)
                    end
                end

                CHECK: begin
                    if (n > m) begin
                        state <= ERROR_STATE;
                        result <= 8'd0;
                    end else begin
                        state <= SUMMING;
                        sum_reg <= 16'd0;
                        iteration_counter <= 9'd0;
                        // Calculate count = m - n + 1
                        count_reg <= (m - n + 8'd1);
                        current_n <= n;
                    end
                end

                SUMMING: begin
                    if (iteration_counter < count_reg) begin
                        // Add current_n to sum
                        sum_reg <= sum_reg + {8'd0, current_n};
                        current_n <= current_n + 8'd1;
                        iteration_counter <= iteration_counter + 9'd1;
                    end else begin
                        state <= CALC;
                        numerator <= sum_reg;
                        denominator <= count_reg[7:0];  // Convert 9-bit to 8-bit (max 256)
                        // Start division with rounding: (sum + count/2) / count
                        div_num <= sum_reg + {7'd0, count_reg[8:1]};  // count/2
                        div_den <= count_reg[7:0];
                        div_start <= 1'b1;
                        div_busy <= 1'b1;
                        div_count <= 8'd0;
                    end
                end

                CALC: begin
                    // Perform division: divide numerator by denominator
                    if (div_busy) begin
                        if (div_count < 8'd16) begin  // Max 16 iterations for 16-bit
                            div_count <= div_count + 8'd1;
                            // Binary long division algorithm
                            if (div_num >= {8'd0, div_den}) begin
                                div_num <= div_num - {8'd0, div_den};
                                // We need to shift the quotient into another reg
                                // For simplicity, we'll use a different approach
                            end
                            // Shifting logic is complex for long division
                            // Use simpler iterative subtraction approach
                        end else begin
                            div_busy <= 1'b0;
                            div_done <= 1'b1;
                        end
                    end
                    
                    // Alternative: Use built-in division simulation
                    // Since we're synthesizing, we need a proper divider
                    // Let's implement a sequential divider
                    
                    if (div_start) begin
                        div_num <= numerator;
                        div_den <= denominator;
                        div_count <= 8'd0;
                        calc_result <= 16'd0;
                    end
                    
                    if (div_busy) begin
                        // Shift-subtract division algorithm
                        if (div_count < 8'd16) begin
                            div_num <= div_num << 1;
                            calc_result <= calc_result << 1;
                            if (div_num[15:8] >= div_den) begin
                                div_num <= div_num - {8'd0, div_den};
                                calc_result[0] <= 1'b1;
                            end
                            div_count <= div_count + 8'd1;
                        end else begin
                            div_busy <= 1'b0;
                            state <= DONE;
                            result <= calc_result[7:0];
                            valid <= 1'b1;
                        end
                    end
                end

                DONE: begin
                    state <= IDLE;
                end

                ERROR_STATE: begin
                    error <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule