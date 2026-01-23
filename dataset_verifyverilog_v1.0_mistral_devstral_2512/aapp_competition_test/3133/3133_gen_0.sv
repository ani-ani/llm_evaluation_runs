module pisa_levitation (
    input clk,
    input rst_n,
    input start,
    input [3:0] A,
    input [3:0] B,
    input [3:0] left [0:7],
    input [3:0] right [0:7],
    input [0:7] t,
    output reg [8:0] result,
    output reg done
);

parameter N = 8;

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] CHECK = 3'b001;
localparam [2:0] ENQUEUE_LEFT = 3'b010;
localparam [2:0] ENQUEUE_RIGHT = 3'b011;
localparam [2:0] SWAP = 3'b100;
localparam [2:0] DONE = 3'b101;
localparam [2:0] INDIST = 3'b110;

reg [2:0] state;
reg [255:0] visited;
reg [7:0] queue_curr [0:255];
reg [7:0] queue_next [0:255];
reg [7:0] curr_read_ptr;
reg [7:0] curr_write_ptr;
reg [7:0] next_write_ptr;
reg [7:0] curr_count;
reg [7:0] next_count;
reg [7:0] step;
reg [3:0] a;
reg [3:0] b;
reg [3:0] next_a;
reg [3:0] next_b;
reg [7:0] state_index;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        visited <= 256'b0;
        curr_read_ptr <= 8'd0;
        curr_write_ptr <= 8'd0;
        next_write_ptr <= 8'd0;
        curr_count <= 8'd0;
        next_count <= 8'd0;
        step <= 8'd0;
        done <= 1'b0;
        result <= 9'd0;
        for (i = 0; i < 256; i = i + 1) begin
            queue_curr[i] <= 8'd0;
            queue_next[i] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    visited <= 256'b0;
                    visited[{A,B}] <= 1'b1;
                    queue_curr[0] <= {A,B};
                    curr_write_ptr <= 8'd1;
                    curr_count <= 8'd1;
                    step <= 8'd0;
                    done <= 1'b0;
                    state <= CHECK;
                end
            end

            CHECK: begin
                if (curr_count == 0) begin
                    if (next_count == 0) begin
                        state <= INDIST;
                    end else begin
                        state <= SWAP;
                    end
                end else begin
                    state_index <= queue_curr[curr_read_ptr];
                    a <= queue_curr[curr_read_ptr][7:4];
                    b <= queue_curr[curr_read_ptr][3:0];
                    curr_read_ptr <= curr_read_ptr + 1;
                    curr_count <= curr_count - 1;
                    if (t[a] != t[b]) begin
                        result <= {1'b0, step};
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        state <= ENQUEUE_LEFT;
                    end
                end
            end

            ENQUEUE_LEFT: begin
                next_a <= left[a];
                next_b <= left[b];
                if (!visited[{next_a, next_b}]) begin
                    visited[{next_a, next_b}] <= 1'b1;
                    queue_next[next_write_ptr] <= {next_a, next_b};
                    next_write_ptr <= next_write_ptr + 1;
                    next_count <= next_count + 1;
                end
                state <= ENQUEUE_RIGHT;
            end

            ENQUEUE_RIGHT: begin
                next_a <= right[a];
                next_b <= right[b];
                if (!visited[{next_a, next_b}]) begin
                    visited[{next_a, next_b}] <= 1'b1;
                    queue_next[next_write_ptr] <= {next_a, next_b};
                    next_write_ptr <= next_write_ptr + 1;
                    next_count <= next_count + 1;
                end
                state <= CHECK;
            end

            SWAP: begin
                curr_read_ptr <= 8'd0;
                curr_write_ptr <= next_write_ptr;
                curr_count <= next_count;
                next_write_ptr <= 8'd0;
                next_count <= 8'd0;
                step <= step + 1;
                state <= CHECK;
            end

            DONE: begin
                // Stay here until reset
            end

            INDIST: begin
                result <= {1'b1, 8'd0};
                done <= 1'b1;
                state <= DONE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule