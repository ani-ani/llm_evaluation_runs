module coprime_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] a, b, c, d,
    output wire [15:0] result,
    output wire done
);

// Internal registers
reg [3:0] x_reg, y_reg;
reg [15:0] count_reg;
reg done_reg;
reg [2:0] state;

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE_GCD = 3'd1;
localparam [2:0] CHECK_GCD = 3'd2;
localparam [2:0] INCR_Y = 3'd3;
localparam [2:0] INCR_X = 3'd4;
localparam [2:0] DONE = 3'd5;

// GCD function (fixed-step Euclidean algorithm for numbers <= 16, up to 6 steps)
function automatic [3:0] gcd;
    input [3:0] a;
    input [3:0] b;
    reg [3:0] x, y, temp;
    begin
        x = a;
        y = b;
        // Step 1
        if (y != 0) begin
            temp = y;
            y = x % y;
            x = temp;
        end
        // Step 2
        if (y != 0) begin
            temp = y;
            y = x % y;
            x = temp;
        end
        // Step 3
        if (y != 0) begin
            temp = y;
            y = x % y;
            x = temp;
        end
        // Step 4
        if (y != 0) begin
            temp = y;
            y = x % y;
            x = temp;
        end
        // Step 5
        if (y != 0) begin
            temp = y;
            y = x % y;
            x = temp;
        end
        // Step 6
        if (y != 0) begin
            temp = y;
            y = x % y;
            x = temp;
        end
        gcd = x;
    end
endfunction

// Combinational gcd value for current x_reg and y_reg
wire [3:0] current_gcd;
assign current_gcd = gcd(x_reg, y_reg);

// State machine and sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_reg <= 4'd0;
        y_reg <= 4'd0;
        count_reg <= 16'd0;
        done_reg <= 1'b0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                done_reg <= 1'b0;
                if (start) begin
                    x_reg <= a;
                    y_reg <= c;
                    count_reg <= 16'd0;
                    state <= COMPUTE_GCD;
                end
            end

            COMPUTE_GCD: begin
                // GCD is computed combinationally, move to check
                state <= CHECK_GCD;
            end

            CHECK_GCD: begin
                if (current_gcd == 4'd1) begin
                    count_reg <= count_reg + 16'd1;
                end
                state <= INCR_Y;
            end

            INCR_Y: begin
                if (y_reg < d) begin
                    y_reg <= y_reg + 4'd1;
                    state <= COMPUTE_GCD;
                end else begin
                    y_reg <= c;  // reset to c for next x
                    state <= INCR_X;
                end
            end

            INCR_X: begin
                if (x_reg < b) begin
                    x_reg <= x_reg + 4'd1;
                    state <= COMPUTE_GCD;
                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                done_reg <= 1'b1;
                // Wait for start to go low, then return to IDLE for next computation
                if (!start) begin
                    state <= IDLE;
                    done_reg <= 1'b0;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

assign result = count_reg;
assign done = done_reg;

endmodule