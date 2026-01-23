module rocket_fuel_calculator (
    input clk,
    input rst_n,
    input start,
    input [15:0] payload,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    input [7:0] num_planets,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        PREPARE,
        LOOP,
        DIVIDE,
        FINAL,
        DONE,
        ERROR
    } state_t;

    state_t state;
    reg [31:0] current_weight;
    reg [2:0] i;
    reg [31:0] temp_val;
    reg [31:0] denom;
    reg [31:0] quotient;
    reg [5:0] div_cycle;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_weight <= 0;
            i <= 0;
            temp_val <= 0;
            denom <= 0;
            quotient <= 0;
            div_cycle <= 0;
            result <= 0;
            done <= 0;
            error <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PREPARE;
                    end
                end
                PREPARE: begin
                    current_weight <= payload << 16;
                    i <= num_planets - 1;
                    state <= LOOP;
                end
                LOOP: begin
                    if (i >= 0) begin
                        // Landing
                        denom <= (b[i] << 16) - (1 << 16);
                        if (denom <= 0) begin
                            state <= ERROR;
                        end else begin
                            temp_val <= current_weight;
                            state <= DIVIDE;
                        end
                    end else begin
                        state <= FINAL;
                    end
                end
                DIVIDE: begin
                    if (div_cycle == 0) begin
                        quotient <= 0;
                    end
                    if (div_cycle < 32) begin
                        quotient[31:0] <= quotient[31:0] << 1;
                        if (temp_val[31:0] >= denom[31:0]) begin
                            quotient[0] <= 1;
                            temp_val[31:0] <= temp_val[31:0] - denom[31:0];
                        end
                        div_cycle <= div_cycle + 1;
                    end else begin
                        current_weight <= quotient;
                        div_cycle <= 0;
                        // Take-off
                        denom <= (a[i] << 16) - (1 << 16);
                        if (denom <= 0) begin
                            state <= ERROR;
                        end else begin
                            temp_val <= current_weight;
                            state <= DIVIDE;
                        end
                    end
                end
                FINAL: begin
                    denom <= (a[0] << 16) - (1 << 16);
                    if (denom <= 0) begin
                        state <= ERROR;
                    end else begin
                        temp_val <= current_weight;
                        state <= DIVIDE;
                    end
                end
                DONE: begin
                    result <= current_weight - (payload << 16);
                    done <= 1;
                end
                ERROR: begin
                    error <= 1;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (state == DIVIDE && div_cycle == 32) begin
            i <= i - 1;
            state <= LOOP;
        end else if (state == DIVIDE && div_cycle == 32 && i == 0) begin
            state <= DONE;
        end
    end

endmodule