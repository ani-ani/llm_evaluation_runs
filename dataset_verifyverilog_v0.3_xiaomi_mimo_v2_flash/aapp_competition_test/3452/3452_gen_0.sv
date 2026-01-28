module MazeAnalyzer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] degree [0:7],
    input wire [7:0] adj [0:7][0:7],
    output reg [31:0] signature [0:7],
    output reg done
);

    // Parameters
    localparam [3:0] N = 4'd8;
    localparam [3:0] DEG_W = 4'd4;
    localparam [5:0] SIG_W = 6'd32;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RESET = 3'd1;
    localparam [2:0] COMPUTE_SIGNATURE = 3'd2;
    localparam [2:0] NEXT_ROOM = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] room_idx;
    reg [3:0] neighbor_idx;
    reg [7:0] neighbor_accum [0:7];
    reg [3:0] i;
    
    // Wire declarations for computation
    wire [15:0] own_degree_shifted;
    wire [15:0] neighbor_sum_shifted;
    wire [31:0] signature_temp;
    
    // Computation logic
    assign own_degree_shifted = {8'd0, degree[room_idx]};
    assign neighbor_sum_shifted = {neighbor_accum[room_idx], 4'd0};
    assign signature_temp = own_degree_shifted + neighbor_sum_shifted;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            room_idx <= 4'd0;
            neighbor_idx <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                signature[i] <= 32'd0;
                neighbor_accum[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    room_idx <= 4'd0;
                    neighbor_idx <= 4'd0;
                    if (start) begin
                        state <= RESET;
                    end
                end
                
                RESET: begin
                    // Clear neighbor accumulators for current room
                    for (i = 0; i < 8; i = i + 1) begin
                        neighbor_accum[i] <= 8'd0;
                    end
                    state <= COMPUTE_SIGNATURE;
                end
                
                COMPUTE_SIGNATURE: begin
                    // Sum neighbor degrees for current room
                    if (neighbor_idx < N) begin
                        if (adj[room_idx][neighbor_idx] == 8'h01) begin
                            neighbor_accum[room_idx] <= neighbor_accum[room_idx] + degree[neighbor_idx];
                        end
                        neighbor_idx <= neighbor_idx + 4'd1;
                    end else begin
                        // All neighbors processed, compute final signature
                        signature[room_idx] <= signature_temp[31:0];
                        state <= NEXT_ROOM;
                        neighbor_idx <= 4'd0;
                    end
                end
                
                NEXT_ROOM: begin
                    if (room_idx < (N - 4'd1)) begin
                        room_idx <= room_idx + 4'd1;
                        state <= RESET;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule