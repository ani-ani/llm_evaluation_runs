module TopModule(
    input clk,
    input areset,
    input bump_left,
    input bump_right,
    input ground,
    output logic walk_left,
    output logic walk_right,
    output logic aaah
);
    typedef enum logic[1:0] {WALK_LEFT, WALK_RIGHT, FALL_LEFT, FALL_RIGHT} state_t;
    state_t state;
    always_ff @(posedge clk or posedge areset) begin
        if (areset) begin
            state <= WALK_LEFT;
        end else begin
            case (state)
                WALK_LEFT: begin
                    if (!ground) begin
                        state <= FALL_LEFT;
                    end else if (bump_left || bump_right) begin
                        state <= WALK_RIGHT;
                    end else begin
                        state <= WALK_LEFT;
                    end
                end
                WALK_RIGHT: begin
                    if (!ground) begin
                        state <= FALL_RIGHT;
                    end else if (bump_left || bump_right) begin
                        state <= WALK_LEFT;
                    end else begin
                        state <= WALK_RIGHT;
                    end
                end
                FALL_LEFT: begin
                    if (ground) begin
                        state <= WALK_LEFT;
                    end else begin
                        state <= FALL_LEFT;
                    end
                end
                FALL_RIGHT: begin
                    if (ground) begin
                        state <= WALK_RIGHT;
                    end else begin
                        state <= FALL_RIGHT;
                    end
                end
            endcase
        end
    end
    always_comb begin
        walk_left = 0;
        walk_right = 0;
        aaah = 0;
        case (state)
            WALK_LEFT: walk_left = 1;
            WALK_RIGHT: walk_right = 1;
            default: aaah = 1;
        endcase
    end
endmodule