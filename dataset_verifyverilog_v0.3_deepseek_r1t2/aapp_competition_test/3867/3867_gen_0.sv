module bfs_validator #(
    parameter N = 8,
    parameter DATA_WIDTH = 8,
    parameter MAX_CYCLES = 100
)(
    input clk,
    input rst_n,
    input start,
    
    input [DATA_WIDTH-1:0] adj_0,
    input [DATA_WIDTH-1:0] adj_1,
    input [DATA_WIDTH-1:0] adj_2,
    input [DATA_WIDTH-1:0] adj_3,
    input [DATA_WIDTH-1:0] adj_4,
    input [DATA_WIDTH-1:0] adj_5,
    input [DATA_WIDTH-1:0] adj_6,
    input [DATA_WIDTH-1:0] adj_7,
    
    input [DATA_WIDTH-1:0] seq_0,
    input [DATA_WIDTH-1:0] seq_1,
    input [DATA_WIDTH-1:0] seq_2,
    input [DATA_WIDTH-1:0] seq_3,
    input [DATA_WIDTH-1:0] seq_4,
    input [DATA_WIDTH-1:0] seq_5,
    input [DATA_WIDTH-1:0] seq_6,
    input [DATA_WIDTH-1:0] seq_7,
    
    output reg valid,
    output reg done
);

localparam [2:0] IDLE           = 3'd0;
localparam [2:0] CHECK_START    = 3'd1;
localparam [2:0] GET_NEIGHBORS  = 3'd2;
localparam [2:0] VERIFY_CHILDREN= 3'd3;
localparam [2:0] UPDATE_QUEUE   = 3'd4;
localparam [2:0] FINISHED       = 3'd5;

reg [2:0] state, next_state;
reg [7:0] queue;
reg [7:0] visited;
reg [2:0] head_ptr;
reg [2:0] child_ptr;
reg [2:0] current_node;
reg [7:0] neighbor_mask;
reg [2:0] neighbor_count;
reg [2:0] verify_count;
reg [7:0] cycle_count;

wire [7:0] current_adj;
assign current_adj = (current_node == 3'd0) ? adj_0 :
                     (current_node == 3'd1) ? adj_1 :
                     (current_node == 3'd2) ? adj_2 :
                     (current_node == 3'd3) ? adj_3 :
                     (current_node == 3'd4) ? adj_4 :
                     (current_node == 3'd5) ? adj_5 :
                     (current_node == 3'd6) ? adj_6 : adj_7;

wire [7:0] seq_head;
assign seq_head = (head_ptr == 3'd0) ? seq_0 :
                  (head_ptr == 3'd1) ? seq_1 :
                  (head_ptr == 3'd2) ? seq_2 :
                  (head_ptr == 3'd3) ? seq_3 :
                  (head_ptr == 3'd4) ? seq_4 :
                  (head_ptr == 3'd5) ? seq_5 :
                  (head_ptr == 3'd6) ? seq_6 : seq_7;

wire [7:0] child_seq;
assign child_seq = (child_ptr == 3'd0) ? seq_0 :
                   (child_ptr == 3'd1) ? seq_1 :
                   (child_ptr == 3'd2) ? seq_2 :
                   (child_ptr == 3'd3) ? seq_3 :
                   (child_ptr == 3'd4) ? seq_4 :
                   (child_ptr == 3'd5) ? seq_5 :
                   (child_ptr == 3'd6) ? seq_6 : seq_7;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        valid <= 1'b0;
        done <= 1'b0;
        queue <= 8'd0;
        visited <= 8'd0;
        head_ptr <= 3'd0;
        child_ptr <= 3'd0;
        current_node <= 3'd0;
        neighbor_mask <= 8'd0;
        neighbor_count <= 3'd0;
        verify_count <= 3'd0;
        cycle_count <= 8'd0;
    end else begin
        state <= next_state;
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            IDLE: begin
                valid <= 1'b0;
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    queue <= 8'd0;
                    visited <= 8'd0;
                    head_ptr <= 3'd0;
                end
            end
            
            CHECK_START: begin
                if (seq_head != 8'd0) begin
                    valid <= 1'b0;
                    next_state <= FINISHED;
                end else begin
                    visited <= 8'b00000001;
                    queue <= 8'b00000001;
                    head_ptr <= 3'd1;
                    current_node <= 3'd0;
                    valid <= 1'b1;
                end
            end
            
            GET_NEIGHBORS: begin
                neighbor_mask <= current_adj & ~visited;
                neighbor_count <= 3'd0;
                for (integer i=0; i<8; i=i+1) begin
                    if (neighbor_mask[i]) neighbor_count <= neighbor_count + 3'd1;
                end
                child_ptr <= head_ptr;
                verify_count <= 3'd0;
            end
            
            VERIFY_CHILDREN: begin
                if (child_ptr < 3'd8) begin
                    if (child_seq < 8'd8 && neighbor_mask[child_seq]) begin
                        verify_count <= verify_count + 3'd1;
                    end else begin
                        valid <= 1'b0;
                    end
                    child_ptr <= child_ptr + 3'd1;
                end
            end
            
            UPDATE_QUEUE: begin
                queue[current_node] <= 1'b0;
                for (integer i=0; i<8; i=i+1) begin
                    if (neighbor_mask[i]) begin
                        visited[i] <= 1'b1;
                        queue[i] <= 1'b1;
                    end
                end
                head_ptr <= head_ptr + neighbor_count;
                
                // Find next node in queue
                current_node <= 3'd0;
                for (integer i=0; i<8; i=i+1) begin
                    if (queue[i]) current_node <= i;
                end
            end
            
            FINISHED: begin
                done <= 1'b1;
                if (cycle_count >= MAX_CYCLES) valid <= 1'b0;
            end
        endcase
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: next_state = start ? CHECK_START : IDLE;
        CHECK_START: next_state = GET_NEIGHBORS;
        GET_NEIGHBORS: next_state = (queue == 8'd0) ? FINISHED : VERIFY_CHILDREN;
        VERIFY_CHILDREN: begin
            if (verify_count >= neighbor_count || child_ptr >= N || !valid)
                next_state = UPDATE_QUEUE;
            else if (cycle_count >= MAX_CYCLES)
                next_state = FINISHED;
        end
        UPDATE_QUEUE: next_state = (head_ptr >= N) ? FINISHED : GET_NEIGHBORS;
        FINISHED: next_state = FINISHED;
        default: next_state = IDLE;
    endcase
end

endmodule