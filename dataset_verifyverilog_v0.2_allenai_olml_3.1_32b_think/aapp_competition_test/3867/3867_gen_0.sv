module bfs_validator (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_idx,         // Current node index for adjacency input
    input [2:0] neighbor_idx,     // Neighbor node index for adjacency input
    input adj_write,              // Write enable for adjacency matrix
    input [2:0] seq_in,           // Next element of sequence to validate
    input seq_write,              // Write enable for sequence input
    output reg valid,             // High if sequence is valid BFS traversal
    output reg done               // High when validation is complete
);

// Internal registers
reg [7:0] adj_matrix [8][8];
reg [7:0] sequence [8];
reg [7:0] visited [8];
reg [7:0] parent [8];
reg [3:0] state;

// Control signals
reg [7:0] current_seq_pos;
reg [3:0] neighbor_count;
reg [2:0] current_node;

// Counters for LOAD states
reg [2:0] load_adj_counter;
reg [2:0] load_seq_counter;

// State definitions
localparam IDLE = 4'd0;
localparam LOAD_ADJ = 4'd1;
localparam LOAD_SEQ = 4'd2;
localparam VERIFY_INIT = 4'd3;
localparam VERIFY_PROCESS = 4'd4;
localparam VALID_DONE = 4'd5;
localparam INVALID_DONE = 4'd6;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        adj_matrix <= 8'b0;
        sequence <= 8'b0;
        visited <= 8'b0;
        parent <= 8'b0;
        state <= IDLE;
        current_seq_pos <= 8'b0;
        neighbor_count <= 4'b0;
        current_node <= 3'b0;
        load_adj_counter <= 3'b0;
        load_seq_counter <= 3'b0;
        valid <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD_ADJ;
                end
            end
            LOAD_ADJ: begin
                if (load_adj_counter < 8) begin
                    load_adj_counter <= load_adj_counter + 1;
                    if (adj_write) begin
                        adj_matrix[node_idx][neighbor_idx] <= 1;
                    end
                end else begin
                    state <= LOAD_SEQ;
                    load_adj_counter <= 3'b0;
                end
            end
            LOAD_SEQ: begin
                if (load_seq_counter < 8) begin
                    if (seq_write) begin
                        sequence[load_seq_counter] <= seq_in;
                    end
                    load_seq_counter <= load_seq_counter + 1;
                end else begin
                    state <= VERIFY_INIT;
                    load_seq_counter <= 3'b0;
                end
            end
            VERIFY_INIT: begin
                if (sequence[0] != 3'b0) begin
                    state <= INVALID_DONE;
                end else begin
                    visited <= 8'b0;
                    visited[0] <= 1;
                    state <= VERIFY_PROCESS;
                    current_seq_pos <= 8'b1;
                end
            end
            VERIFY_PROCESS: begin
                if (current_seq_pos < 8) begin
                    current_seq_pos <= current_seq_pos + 1;
                end else begin
                    state <= VALID_DONE;
                end
            end
            VALID_DONE: begin
                valid <= 1'b1;
                done <= 1'b1;
            end
            INVALID_DONE: begin
                valid <= 1'b0;
                done <= 1'b1;
            end
        endcase
    end
end