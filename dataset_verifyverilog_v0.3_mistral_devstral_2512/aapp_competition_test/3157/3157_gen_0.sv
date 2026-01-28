module hash_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [24:0] K,
    input wire [4:0] M,
    output reg [47:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] COMPUTE = 3'b001;
    localparam [2:0] UPDATE = 3'b010;
    localparam [2:0] CHECK_DONE = 3'b011;
    localparam [2:0] FINISH = 3'b100;

    reg [2:0] state;
    reg [3:0] len_counter;
    reg [24:0] state_counter;
    reg [4:0] letter_counter;

    reg [47:0] dp_current [0:255];
    reg [47:0] dp_next [0:255];

    wire [24:0] MOD = (1 << M);
    wire [24:0] MOD_MASK = MOD - 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 48'd0;
            len_counter <= 4'd0;
            state_counter <= 25'd0;
            letter_counter <= 5'd0;

            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                dp_current[i] <= 48'd0;
                dp_next[i] <= 48'd0;
            end
            dp_current[0] <= 48'd1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        integer i;
                        for (i = 0; i < 256; i = i + 1) begin
                            dp_next[i] <= 48'd0;
                        end
                        len_counter <= 4'd1;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (letter_counter < 26) begin
                        reg [24:0] new_state;
                        new_state = ((state_counter * 33) ^ (letter_counter + 1)) & MOD_MASK;
                        dp_next[new_state] <= dp_next[new_state] + dp_current[state_counter];
                        letter_counter <= letter_counter + 1;
                    end else begin
                        letter_counter <= 5'd0;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    if (state_counter < MOD && state_counter < 255) begin
                        state_counter <= state_counter + 1;
                        state <= COMPUTE;
                    end else begin
                        state_counter <= 25'd0;
                        state <= CHECK_DONE;
                    end
                end

                CHECK_DONE: begin
                    integer i;
                    for (i = 0; i < 256; i = i + 1) begin
                        if (i < MOD) begin
                            dp_current[i] <= dp_next[i];
                            dp_next[i] <= 48'd0;
                        end else begin
                            dp_current[i] <= 48'd0;
                            dp_next[i] <= 48'd0;
                        end
                    end

                    if (len_counter >= N) begin
                        state <= FINISH;
                    end else begin
                        len_counter <= len_counter + 1;
                        state <= COMPUTE;
                    end
                end

                FINISH: begin
                    if (K < MOD) begin
                        result <= dp_current[K];
                    end else begin
                        result <= 48'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule