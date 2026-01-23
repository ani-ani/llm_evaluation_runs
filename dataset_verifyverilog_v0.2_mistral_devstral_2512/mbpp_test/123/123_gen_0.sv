module amicable_sum (
    input clk,
    input rst_n,
    input start,
    input [7:0] limit,
    output reg [15:0] result,
    output reg done,
    output reg error
);

    parameter NUM_MAX = 100;
    
    typedef enum logic [2:0] {
        IDLE,
        CHECK_INPUT,
        PROCESS,
        VALIDATE,
        SUM_UP,
        DONE
    } state_t;
    
    state_t state, next_state;
    
    reg [7:0] curr_num;
    reg [7:0] div;
    reg [15:0] div_sum [0:NUM_MAX];
    reg [15:0] sum_reg;
    reg [7:0] i, j;
    reg [15:0] temp_result;
    reg [NUM_MAX:0] amicable_set;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            curr_num <= 0;
            div <= 0;
            sum_reg <= 0;
            i <= 0;
            j <= 0;
            temp_result <= 0;
            amicable_set <= 0;
            result <= 0;
            done <= 0;
            error <= 0;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_INPUT;
            end
            CHECK_INPUT: begin
                if (limit < 2) begin
                    error = 1;
                    next_state = DONE;
                end else begin
                    error = 0;
                    next_state = PROCESS;
                end
            end
            PROCESS: begin
                if (curr_num == 0) begin
                    curr_num = 2;
                    div = 1;
                    sum_reg = 0;
                end else if (div < curr_num) begin
                    if (curr_num % div == 0) begin
                        sum_reg = sum_reg + div;
                    end
                    div = div + 1;
                end else begin
                    div_sum[curr_num] = sum_reg;
                    if (curr_num == limit) begin
                        next_state = VALIDATE;
                        i = 2;
                        j = 2;
                    end else begin
                        curr_num = curr_num + 1;
                        div = 1;
                        sum_reg = 0;
                    end
                end
            end
            VALIDATE: begin
                if (i < limit) begin
                    if (j < limit) begin
                        if (div_sum[i] == j && div_sum[j] == i && i != j) begin
                            amicable_set[i] = 1;
                            amicable_set[j] = 1;
                        end
                        j = j + 1;
                    end else begin
                        i = i + 1;
                        j = i + 1;
                    end
                end else begin
                    next_state = SUM_UP;
                    i = 2;
                    temp_result = 0;
                end
            end
            SUM_UP: begin
                if (i <= limit) begin
                    if (amicable_set[i]) begin
                        temp_result = temp_result + i;
                    end
                    if (i == limit) begin
                        next_state = DONE;
                        result = temp_result;
                        done = 1;
                    end else begin
                        i = i + 1;
                    end
                end
            end
            DONE: begin
                if (!rst_n) begin
                    next_state = IDLE;
                    done = 0;
                    error = 0;
                end
            end
        endcase
    end

endmodule