module starts_one_ends(
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    output reg [31:0] result,
    output reg done
);

// State encoding
localparam IDLE = 3'b001;
localparam CALC_10_POW = 3'b010;
localparam CALC_FINAL = 3'b100;

reg [2:0] state;
reg [2:0] next_state;

// LUT for 10^(n-1) where index 0 corresponds to n=1
wire [31:0] pow10_n_minus_1 [0:5];
assign pow10_n_minus_1[0] = 1;          // 10^0 for n=1
assign pow10_n_minus_1[1] = 10;         // 10^1 for n=2
assign pow10_n_minus_1[2] = 100;        // 10^2 for n=3
assign pow10_n_minus_1[3] = 1000;       // 10^3 for n=4
assign pow10_n_minus_1[4] = 10000;      // 10^4 for n=5
assign pow10_n_minus_1[5] = 100000;     // 10^5 for n=6

reg [31:0] pow10_val;   // Stores 10^(n-2) for n>=2
reg [31:0] temp_result; // Intermediate result

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state; // Default to stay in current state
    case (state)
        IDLE: begin
            if (start)
                next_state = CALC_10_POW;
        end
        CALC_10_POW: begin
            next_state = CALC_FINAL;
        end
        CALC_FINAL: begin
            next_state = DONE;
        end
        DONE: begin
            if (!start) // Wait for start to go low to return to IDLE
                next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Output logic and data processing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result <= 32'b0;
        done <= 1'b0;
        pow10_val <= 32'b0;
        temp_result <= 32'b0;
    end else begin
        case (next_state)
            IDLE: begin
                done <= 1'b0;
            end
            
            CALC_10_POW: begin
                // Determine pow10_val: 10^(n-2) for n>=2
                // If n=1 (which is index 0 in pow10_n_minus_1), we don't use pow10_val for calculation
                if (n >= 2 && n <= 6) begin
                    // pow10_n_minus_1[n-2] is 10^(n-2) because:
                    // pow10_n_minus_1[0] = 10^0 = 1 (which is 10^(2-2) for n=2)
                    // pow10_n_minus_1[1] = 10^1 = 10 (which is 10^(3-2) for n=3)
                    // So index = n - 2
                    if (n == 2) pow10_val <= pow10_n_minus_1[0];
                    else if (n == 3) pow10_val <= pow10_n_minus_1[1];
                    else if (n == 4) pow10_val <= pow10_n_minus_1[2];
                    else if (n == 5) pow10_val <= pow10_n_minus_1[3];
                    else if (n == 6) pow10_val <= pow10_n_minus_1[4];
                end
            end
            
            CALC_FINAL: begin
                if (n == 1) begin
                    result <= 1;
                end else if (n >= 2 && n <= 6) begin
                    // Compute 18 * pow10_val = (pow10_val << 4) + (pow10_val << 1)
                    // (pow10_val << 4) = 16 * pow10_val
                    // (pow10_val << 1) = 2 * pow10_val
                    // Sum = 18 * pow10_val
                    result <= (pow10_val << 4) + (pow10_val << 1);
                end
            end
            
            DONE: begin
                done <= 1'b1;
            end
            
            default: begin
                result <= 32'b0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule
