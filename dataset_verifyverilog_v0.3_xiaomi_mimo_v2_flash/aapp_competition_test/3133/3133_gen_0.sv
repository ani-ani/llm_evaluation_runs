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
localparam [2:0] IDLE       = 3'b000;
localparam [2:0] CHECK      = 3'b001;
localparam [2:0] ENQUEUE_LEFT = 3'b010;
localparam [2:0] ENQUEUE_RIGHT = 3'b011;
localparam [2:0] SWAP       = 3'b100;
localparam [2:0] DONE_STATE = 3'b101;
localparam [2:0] INDIST     = 3'b110;

reg [2:0] state, next_state;
reg [255:0] visited;
reg [7:0] queue_curr [0:255];
reg [7:0] queue_next [0:255];
reg [7:0] curr_read_ptr, curr_write_ptr;
reg [7:0] next_write_ptr;
reg [7:0] curr_count, next_count;
reg [7:0] step;
reg [3:0] a, b, next_a, next_b;
reg [7:0] state_index;
integer i;

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) next_state = CHECK;
            else next_state = IDLE;
        end
        CHECK: begin
            if (curr_count == 0) begin
                if (next_count == 0) next_state = INDIST;
                else next_state = SWAP;
            end else begin
                if (t[a] != t[b]) next_state = DONE_STATE;
                else next_state = ENQUEUE_LEFT;
            end
        end
        ENQUEUE_LEFT: next_state = ENQUEUE_RIGHT;
        ENQUEUE_RIGHT: next_state = CHECK;
        SWAP: next_state = CHECK;
        DONE_STATE: next_state = DONE_STATE;
        INDIST: next_state = DONE_STATE;
        default: next_state = IDLE;
    endcase
end

// State register and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        visited <= 256'b0;
        curr_read_ptr <= 8'b0;
        curr_write_ptr <= 8'b0;
        next_write_ptr <= 8'b0;
        curr_count <= 8'b0;
        next_count <= 8'b0;
        step <= 8'b0;
        done <= 1'b0;
        result <= 9'b0;
        a <= 4'b0;
        b <= 4'b0;
        next_a <= 4'b0;
        next_b <= 4'b0;
        state_index <= 8'b0;
        for (i = 0; i < 256; i = i + 1) begin
            queue_curr[i] <= 8'b0;
            queue_next[i] <= 8'b0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    visited <= 256'b0;
                    visited[{A,B}] <= 1'b1;
                    queue_curr[0] <= {A,B};
                    curr_write_ptr <= 8'b1;
                    curr_count <= 8'b1;
                    step <= 8'b0;
                    done <= 1'b0;
                end
            end

            CHECK: begin
                if (curr_count == 0) begin
                    // No more states in current level
                end else begin
                    state_index <= queue_curr[curr_read_ptr];
                    a <= queue_curr[curr_read_ptr][7:4];
                    b <= queue_curr[curr_read_ptr][3:0];
                    curr_read_ptr <= curr_read_ptr + 8'd1;
                    curr_count <= curr_count - 8'd1;
                    if (t[a] != t[b]) begin
                        result <= {1'b0, step};
                        done <= 1'b1;
                    end
                end
            end

            ENQUEUE_LEFT: begin
                next_a <= left[a];
                next_b <= left[b];
            end

            ENQUEUE_RIGHT: begin
                if (!visited[{next_a, next_b}]) begin
                    visited[{next_a, next_b}] <= 1'b1;
                    queue_next[next_write_ptr] <= {next_a, next_b};
                    next_write_ptr <= next_write_ptr + 8'd1;
                    next_count <= next_count + 8'd1;
                end
            end

            SWAP: begin
                curr_read_ptr <= 8'b0;
                curr_write_ptr <= next_write_ptr;
                curr_count <= next_count;
                next_write_ptr <= 8'b0;
                next_count <= 8'b0;
                step <= step + 8'd1;
            end

            DONE_STATE: begin
                // Stay here until reset
            end

            INDIST: begin
                result <= {1'b1, 8'b0};
                done <= 1'b1;
            end
        endcase
    end
end

endmodule