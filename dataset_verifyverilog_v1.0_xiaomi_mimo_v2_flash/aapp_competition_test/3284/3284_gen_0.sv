module coprime_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] a, b, c, d,
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE         = 3'd0;
localparam [2:0] LOAD         = 3'd1;
localparam [2:0] COMPUTE_GCD  = 3'd2;
localparam [2:0] CHECK_COPRIME = 3'd3;
localparam [2:0] INCR_Y       = 3'd4;
localparam [2:0] INCR_X       = 3'd5;
localparam [2:0] FINISH       = 3'd6;

// Internal registers
reg [2:0] state;
reg [3:0] x_reg, y_reg;
reg [15:0] count_reg;
reg [3:0] gcd_temp_a, gcd_temp_b;
reg [3:0] gcd_iter;
reg [2:0] gcd_step_count;
reg gcd_done;
reg gcd_valid;
reg [7:0] cycle_counter;
localparam [7:0] MAX_CYCLES = 8'd200;

// GCD computation using iterative Euclidean algorithm
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gcd_temp_a <= 4'd0;
        gcd_temp_b <= 4'd0;
        gcd_iter <= 4'd0;
        gcd_step_count <= 3'd0;
        gcd_done <= 1'b0;
        gcd_valid <= 1'b0;
    end else begin
        if (state == COMPUTE_GCD && !gcd_done && !gcd_valid) begin
            gcd_step_count <= gcd_step_count + 3'd1;
            
            if (gcd_temp_b != 4'd0 && gcd_step_count < 3'd4) begin
                // One iteration of Euclidean algorithm
                gcd_temp_a <= gcd_temp_b;
                gcd_temp_b <= gcd_temp_a % gcd_temp_b;
            end else begin
                // GCD computation complete (either b==0 or max steps reached)
                gcd_done <= 1'b1;
                gcd_iter <= gcd_temp_a;
                gcd_valid <= 1'b1;
            end
        end else if (state != COMPUTE_GCD) begin
            // Reset for next computation
            gcd_done <= 1'b0;
            gcd_valid <= 1'b0;
            gcd_step_count <= 3'd0;
        end
    end
end

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        x_reg <= 4'd0;
        y_reg <= 4'd0;
        count_reg <= 16'd0;
        result <= 16'd0;
        done <= 1'b0;
        cycle_counter <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_counter <= 8'd0;
                if (start) begin
                    state <= LOAD;
                end
            end
            
            LOAD: begin
                x_reg <= a;
                y_reg <= c;
                count_reg <= 16'd0;
                state <= COMPUTE_GCD;
            end
            
            COMPUTE_GCD: begin
                cycle_counter <= cycle_counter + 8'd1;
                if (cycle_counter >= MAX_CYCLES) begin
                    // Timeout protection
                    state <= FINISH;
                end else if (gcd_valid) begin
                    // GCD computed
                    state <= CHECK_COPRIME;
                end
            end
            
            CHECK_COPRIME: begin
                // Check if GCD is 1 (coprime)
                if (gcd_iter == 4'd1) begin
                    count_reg <= count_reg + 16'd1;
                end
                state <= INCR_Y;
            end
            
            INCR_Y: begin
                if (y_reg < d) begin
                    y_reg <= y_reg + 4'd1;
                    // Reset GCD state for next computation
                    gcd_temp_a <= x_reg;
                    gcd_temp_b <= y_reg + 4'd1;
                    gcd_done <= 1'b0;
                    gcd_valid <= 1'b0;
                    gcd_step_count <= 3'd0;
                    state <= COMPUTE_GCD;
                end else begin
                    y_reg <= c;
                    state <= INCR_X;
                end
            end
            
            INCR_X: begin
                if (x_reg < b) begin
                    x_reg <= x_reg + 4'd1;
                    // Reset GCD state for next computation
                    gcd_temp_a <= x_reg + 4'd1;
                    gcd_temp_b <= c;
                    gcd_done <= 1'b0;
                    gcd_valid <= 1'b0;
                    gcd_step_count <= 3'd0;
                    state <= COMPUTE_GCD;
                end else begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                result <= count_reg;
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule