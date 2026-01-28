module dial_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] A,
    input wire [3:0] B,
    output reg [6:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] N = 4'd8;          // Number of dials
    localparam [3:0] MAX_DIAL = 4'd9;   // Max dial value
    localparam [3:0] MAX_IDX = 4'd7;    // Max index (0-7)

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONV_A = 3'd1;
    localparam [2:0] CONV_B = 3'd2;
    localparam [2:0] CALC_SUM = 3'd3;
    localparam [2:0] UPDATE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Storage for dial values
    reg [3:0] dials [0:7]; // 8 dials, 4 bits each

    // Registers for FSM
    reg [2:0] state;
    reg [3:0] a_reg;       // 0-indexed start
    reg [3:0] b_reg;       // 0-indexed end
    reg [3:0] idx;         // Current index
    reg [6:0] sum;         // Accumulator (max 8*9=72 fits in 7 bits)
    reg [3:0] temp_a;      // Temporary for conversion
    reg [3:0] temp_b;      // Temporary for conversion

    // Helper variables for loops
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all state variables
            state <= IDLE;
            done <= 1'b0;
            result <= 7'd0;
            idx <= 4'd0;
            sum <= 7'd0;
            a_reg <= 4'd0;
            b_reg <= 4'd0;
            temp_a <= 4'd0;
            temp_b <= 4'd0;
            // Initialize dials to 0
            for (i = 0; i < 8; i = i + 1) begin
                dials[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CONV_A;
                    end
                end

                CONV_A: begin
                    // Convert 1-indexed A to 0-indexed
                    // Clamp A to valid range [1, N]
                    if (A > 4'd0 && A <= N)
                        temp_a <= A - 4'd1;
                    else if (A > N)
                        temp_a <= N - 4'd1; // clamp to max
                    else
                        temp_a <= 4'd0; // if A is 0 or less, clamp to 0
                    state <= CONV_B;
                end

                CONV_B: begin
                    // Convert 1-indexed B to 0-indexed
                    // Clamp B to valid range [1, N]
                    if (B > 4'd0 && B <= N)
                        temp_b <= B - 4'd1;
                    else if (B > N)
                        temp_b <= N - 4'd1;
                    else
                        temp_b <= 4'd0;
                    
                    // Ensure b_reg >= a_reg for loop logic
                    if (temp_b >= temp_a) begin
                        a_reg <= temp_a;
                        b_reg <= temp_b;
                    end else begin
                        // Swap if out of order
                        a_reg <= temp_b;
                        b_reg <= temp_a;
                    end
                    
                    sum <= 7'd0;
                    idx <= temp_a; // Start loop at start index
                    state <= CALC_SUM;
                end

                CALC_SUM: begin
                    if (idx <= b_reg) begin
                        sum <= sum + dials[idx];
                        idx <= idx + 4'd1;
                    end else begin
                        result <= sum;
                        idx <= a_reg;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    if (idx <= b_reg) begin
                        // Increment dial modulo 10
                        if (dials[idx] >= MAX_DIAL)
                            dials[idx] <= 4'd0;
                        else
                            dials[idx] <= dials[idx] + 4'd1;
                        idx <= idx + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                        done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule