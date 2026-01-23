module leader_determination #(
    parameter n = 8,
    parameter m = 16
) (
    input clk,
    input rst_n,
    input [m-1:0] event_type,
    input [4*m-1:0] event_id,
    output reg [n-1:0] possible_leaders,
    output reg done
);

    // State definitions
    localparam [3:0] S_INIT = 4'd0;
    localparam [3:0] S_CHECK_S0 = 4'd1;
    localparam [3:0] S_SIM_START = 4'd2;
    localparam [3:0] S_CHECK_INITIAL = 4'd3;
    localparam [3:0] S_SIM_EVENT = 4'd4;
    localparam [3:0] S_CHECK_EVENT = 4'd5;
    localparam [3:0] S_CHECK_FINAL = 4'd6;
    localparam [3:0] S_UPDATE_CANDIDATE = 4'd7;
    localparam [3:0] S_DONE = 4'd8;

    // Internal registers
    reg [3:0] state;
    reg [3:0] current_candidate;
    reg [7:0] current_S0;
    reg [7:0] current_state;
    reg [3:0] current_event;
    reg found_valid_S0;

    // Event storage
    reg event_type_reg [0:m-1];
    reg [3:0] event_id_reg [0:m-1];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_INIT;
            possible_leaders <= {n{1'b0}};
            done <= 1'b0;
            current_candidate <= 4'd0;
            current_S0 <= 8'd0;
            current_state <= 8'd0;
            current_event <= 4'd0;
            found_valid_S0 <= 1'b0;
            for (i = 0; i < m; i = i + 1) begin
                event_type_reg[i] <= 1'b0;
                event_id_reg[i] <= 4'd0;
            end
        end else begin
            case (state)
                S_INIT: begin
                    current_candidate <= 4'd1;
                    current_S0 <= 8'd0;
                    found_valid_S0 <= 1'b0;
                    for (i = 0; i < m; i = i + 1) begin
                        event_type_reg[i] <= event_type[i];
                        event_id_reg[i] <= event_id[4*i +:4];
                    end
                    state <= S_CHECK_S0;
                end

                S_CHECK_S0: begin
                    if (current_S0 >= (1 << n)) begin
                        if (!found_valid_S0) begin
                            possible_leaders[current_candidate-1] <= 1'b0;
                        end
                        state <= S_UPDATE_CANDIDATE;
                    end else begin
                        if (event_type_reg[0] == 1'b0) begin  // '+' login
                            if (current_S0[event_id_reg[0]-1] == 1'b0) begin
                                state <= S_SIM_START;
                            end else begin
                                current_S0 <= current_S0 + 8'd1;
                            end
                        end else begin  // '-' logout
                            if (current_S0[event_id_reg[0]-1] == 1'b1) begin
                                state <= S_SIM_START;
                            end else begin
                                current_S0 <= current_S0 + 8'd1;
                            end
                        end
                    end
                end

                S_SIM_START: begin
                    current_state <= current_S0;
                    current_event <= 4'd0;
                    state <= S_CHECK_INITIAL;
                end

                S_CHECK_INITIAL: begin
                    if (current_state != 8'd0 && (current_state & (8'd1 << (current_candidate-1))) == 8'd0) begin
                        current_S0 <= current_S0 + 8'd1;
                        state <= S_CHECK_S0;
                    end else begin
                        state <= S_SIM_EVENT;
                    end
                end

                S_SIM_EVENT: begin
                    if (current_event >= m) begin
                        state <= S_CHECK_FINAL;
                    end else begin
                        if (event_type_reg[current_event] == 1'b0) begin
                            current_state <= current_state | (8'd1 << (event_id_reg[current_event]-1));
                        end else begin
                            current_state <= current_state & ~(8'd1 << (event_id_reg[current_event]-1));
                        end
                        state <= S_CHECK_EVENT;
                    end
                end

                S_CHECK_EVENT: begin
                    if (current_state != 8'd0 && (current_state & (8'd1 << (current_candidate-1))) == 8'd0) begin
                        current_S0 <= current_S0 + 8'd1;
                        state <= S_CHECK_S0;
                    end else begin
                        current_event <= current_event + 4'd1;
                        state <= S_SIM_EVENT;
                    end
                end

                S_CHECK_FINAL: begin
                    if (current_state != 8'd0 && (current_state & (8'd1 << (current_candidate-1))) == 8'd0) begin
                        current_S0 <= current_S0 + 8'd1;
                        state <= S_CHECK_S0;
                    end else begin
                        found_valid_S0 <= 1'b1;
                        possible_leaders[current_candidate-1] <= 1'b1;
                        current_S0 <= (8'd1 << n);
                        state <= S_CHECK_S0;
                    end
                end

                S_UPDATE_CANDIDATE: begin
                    if (current_candidate == n) begin
                        state <= S_DONE;
                    end else begin
                        current_candidate <= current_candidate + 4'd1;
                        current_S0 <= 8'd0;
                        found_valid_S0 <= 1'b0;
                        state <= S_CHECK_S0;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    state <= S_DONE;
                end

                default: state <= S_INIT;
            endcase
        end
    end
endmodule