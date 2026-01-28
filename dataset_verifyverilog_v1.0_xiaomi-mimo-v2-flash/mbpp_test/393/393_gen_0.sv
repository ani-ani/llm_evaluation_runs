module MaxLenSublist (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] lists [0:4][0:7],
    input wire [3:0] sublist_lens [0:4],
    output reg [3:0] max_len,
    output reg [2:0] max_idx,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] UPDATE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] idx;  // Sublist index (0-4)
    reg [2:0] current_idx;
    reg [3:0] current_len;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK;
                else
                    next_state = IDLE;
            end
            CHECK: begin
                if (idx < 5'd5)
                    next_state = UPDATE;
                else
                    next_state = FINISH;
            end
            UPDATE: begin
                next_state = CHECK;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_len <= 4'd0;
            max_idx <= 3'd0;
            done <= 1'b0;
            idx <= 3'd0;
            current_len <= 4'd0;
            current_idx <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 3'd0;
                    max_len <= 4'd0;
                    max_idx <= 3'd0;
                    cycle_count <= 8'd0;
                end
                CHECK: begin
                    // Prepare for comparison
                    current_len <= sublist_lens[idx];
                    current_idx <= idx;
                end
                UPDATE: begin
                    if (current_len > max_len) begin
                        max_len <= current_len;
                        max_idx <= current_idx;
                    end
                    idx <= idx + 3'd1;
                end
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
            end
        end
    end

endmodule