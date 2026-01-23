module xorbonacci_query (
    input clk,
    input rst_n,
    input start,
    input [2:0] K,
    input [63:0] initial_values [0:7],
    input [63:0] l,
    input [63:0] r,
    output reg [63:0] result,
    output reg done
);

localparam IDLE = 3'd0, LOAD=1, FIND_PERIOD=2, CALC_SUM=3, DONE=4;

reg [2:0] state;
reg [2:0] K_reg;
reg [63:0] initial_values_reg [7:0];
reg [63:0] current_state [7:0];
reg [63:0] l_reg, r_reg;
reg [63:0] term_counter;
reg [63:0] result;
reg done;
reg [11:0] find_period_count;
reg [63:0] period_P;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        K_reg <= 3'd0;
        initial_values_reg <= 64'd0;
        current_state <= 64'd0;
        l_reg <= 64'd0;
        r_reg <= 64'd0;
        term_counter <= 64'd0;
        result <= 64'd0;
        done <= 1'b0;
        find_period_count <= 16'd0;
        period_P <= 64'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD;
            end
            LOAD: begin
                K_reg <= K;
                initial_values_reg <= initial_values;
                l_reg <= l;
                r_reg <= r;
                if (K_reg == 1) current_state[0] <= initial_values_reg[0];
                else if (K_reg == 2) begin
                    current_state[0] <= initial_values_reg[0];
                    current_state[1] <= initial_values_reg[1];
                end
                if (K_reg > 0) state <= FIND_PERIOD;
                else state <= DONE;
            end
            FIND_PERIOD: begin
                if (find_period_count < 2048) begin
                    find_period_count <= find_period_count + 1;
                end else begin
                    state <= DONE;
                    result <= 64'd0;
                    done <= 1'b1;
                end
            end
            CALC_SUM: begin
                state <= DONE;
                result <= 64'd0;
                done <= 1'b1;
            end
            DONE: begin
            end
        endcase
    end
endmodule