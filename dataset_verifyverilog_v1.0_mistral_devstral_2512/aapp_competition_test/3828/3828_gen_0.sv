module sorted_train(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] p [0:15],
    output reg [7:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] BUILD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] j, k;
    reg [7:0] current_len, max_len;
    reg [7:0] inv [0:15];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            current_len <= 8'd0;
            max_len <= 8'd0;
            cycle_count <= 8'd0;
            
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                inv[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start && n > 8'd0) begin
                    next_state = BUILD;
                end
            end
            
            BUILD: begin
                if (j < n) begin
                    inv[p[j] - 8'd1] = j;
                    j = j + 8'd1;
                end else begin
                    next_state = COMPUTE;
                    k = 8'd1;
                    current_len = 8'd1;
                    max_len = 8'd1;
                end
            end
            
            COMPUTE: begin
                if (k < n) begin
                    if (inv[k] > inv[k - 8'd1]) begin
                        current_len = current_len + 8'd1;
                        if (current_len > max_len) begin
                            max_len = current_len;
                        end
                    end else begin
                        current_len = 8'd1;
                    end
                    k = k + 8'd1;
                end else begin
                    result = n - max_len;
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule