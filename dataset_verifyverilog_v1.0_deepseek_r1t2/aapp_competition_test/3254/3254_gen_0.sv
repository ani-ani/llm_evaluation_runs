module paper_average (
    input clk,
    input rst_n,
    input start,
    input [12:0] P_scaled,
    output reg [7:0] a1,
    output reg [7:0] a2,
    output reg [7:0] a3,
    output reg [7:0] a4,
    output reg [7:0] a5,
    output reg done
);
    
    // FSM States
    localparam [3:0]
        IDLE        = 4'd0,
        INIT_N      = 4'd1,
        CHECK_DIV   = 4'd2,
        CALC_S_D    = 4'd3,
        INIT_A5     = 4'd4,
        TRY_A5      = 4'd5,
        TRY_A4      = 4'd6,
        TRY_A3      = 4'd7,
        STEP_A3     = 4'd8,
        STEP_A4     = 4'd9,
        STEP_A5     = 4'd10,
        UPDATE_N    = 4'd11,
        FOUND       = 4'd12,
        TIMEOUT     = 4'd13;

    reg [3:0] state, next_state;
    reg [7:0] n;
    reg [7:0] a5_cnt, a4_cnt, a3_cnt;
    reg [20:0] product;
    reg [11:0] S, D;
    reg [9:0] remainder;
    wire [31:0] a5_initial, a4_initial, a3_initial;
    wire [31:0] n_remaining, n_remaining2;
    reg [9:0] cycle_count;
    
    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n)
    if (!rst_n)
        cycle_count <= 10'd0;
    else if (state != IDLE)
        cycle_count <= cycle_count + 10'd1;

    // Main FSM
    always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        a1 <= 8'd0;
        a2 <= 8'd0;
        a3 <= 8'd0;
        a4 <= 8'd0;
        a5 <= 8'd0;
        n <= 8'd0;
        a5_cnt <= 8'd0;
        a4_cnt <= 8'd0;
        a3_cnt <= 8'd0;
    end else begin
        case(state)
            IDLE: begin
                done <= 1'b0;
                a1 <= 8'd0;
                a2 <= 8'd0;
                a3 <= 8'd0;
                a4 <= 8'd0;
                a5 <= 8'd0;
                cycle_count <= 10'd0;
                if (start) begin
                    state <= INIT_N;
                    n <= 8'd1;
                end
            end

            INIT_N: begin
                state <= CHECK_DIV;
            end

            CHECK_DIV: begin
                if (cycle_count >= 10'd999) begin
                    state <= TIMEOUT;
                end else begin
                    product = P_scaled * n;
                    remainder = product % 1000;
                    if ((remainder == 10'd0) && (product / 1000 >= n) && (product / 1000 <= {3'd0,n}*5'd5)) begin
                        S <= product / 1000;
                        D <= S - n;
                        state <= CALC_S_D;
                    end else begin
                        if (n == 8'd255) state <= TIMEOUT;
                        else begin
                            n <= n + 8'd1;
                            state <= INIT_N;
                        end
                    end
                end
            end

            CALC_S_D: begin
                state <= INIT_A5;
            end

            INIT_A5: begin
                if (D > (n * 4))
                    a5_cnt <= n;
                else
                    a5_cnt <= D >> 2;
                state <= TRY_A5;
            end

            TRY_A5: begin
                if ((a5_cnt <= n) && ((a5_cnt * 4) <= D)) begin
                    state <= TRY_A4;
                    a4_cnt <= ( (n - a5_cnt) < ( (D - a5_cnt*4) / 3 ) ) ?
                              (n - a5_cnt) : ( (D - a5_cnt*4) / 3 );
                end else 
                    state <= STEP_A5;
            end

            TRY_A4: begin
                if ((a4_cnt <= (n - a5_cnt)) && ((a5_cnt*4 + a4_cnt*3) <= D)) begin
                    state <= TRY_A3;
                    a3_cnt <= ( (n - a5_cnt - a4_cnt) < ( (D - a5_cnt*4 - a4_cnt*3) / 2 ) ) ?
                              (n - a5_cnt - a4_cnt) : ( (D - a5_cnt*4 - a4_cnt*3) >> 1 );
                end else 
                    state <= STEP_A4;
            end

            TRY_A3: begin
                if ((a3_cnt <= (n - a5_cnt - a4_cnt)) && 
                    ((a5_cnt*4 + a4_cnt*3 + a3_cnt*2) <= D) &&
                    ( (D - a5_cnt*4 - a4_cnt*3 - a3_cnt*2) <= (n - a5_cnt - a4_cnt - a3_cnt) ) &&
                    ( (n - a5_cnt - a4_cnt - a3_cnt - (D - a5_cnt*4 - a4_cnt*3 - a3_cnt*2)) >= 0 )) begin
                    
                    // Solution found
                    a5 <= a5_cnt;
                    a4 <= a4_cnt;
                    a3 <= a3_cnt;
                    a2 <= D - a5_cnt*4 - a4_cnt*3 - a3_cnt*2;
                    a1 <= n - a5_cnt - a4_cnt - a3_cnt - (D - a5_cnt*4 - a4_cnt*3 - a3_cnt*2);
                    state <= FOUND;
                end else 
                    state <= STEP_A3;
            end

            STEP_A3: begin
                if (a3_cnt > 8'd0) begin
                    a3_cnt <= a3_cnt - 8'd1;
                    state <= TRY_A3;
                end else 
                    state <= STEP_A4;
            end

            STEP_A4: begin
                if (a4_cnt > 8'd0) begin
                    a4_cnt <= a4_cnt - 8'd1;
                    state <= TRY_A4;
                end else 
                    state <= STEP_A5;
            end

            STEP_A5: begin
                if (a5_cnt > 8'd0) begin
                    a5_cnt <= a5_cnt - 8'd1;
                    state <= TRY_A5;
                end else if (n == 8'd255)
                    state <= TIMEOUT;
                else begin
                    n <= n + 8'd1;
                    state <= INIT_N;
                end
            end

            FOUND: begin
                done <= 1'b1;
                state <= IDLE;
            end

            TIMEOUT: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
endmodule