module MazeAnalyzer(
    input clk,
    input rst_n,
    input start,
    input [3:0] degree [0:7],
    input adj [0:7][0:7],
    output reg [31:0] signature [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RESET = 3'd1;
    localparam [2:0] COMPUTE_SIGNATURE = 3'd2;
    localparam [2:0] NEXT_ROOM = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] current_room;
    reg [2:0] neighbor_index;
    reg [31:0] temp_signature;
    reg [3:0] neighbor_degree_sum;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = RESET;
                else
                    next_state = IDLE;
            end
            RESET: begin
                next_state = COMPUTE_SIGNATURE;
            end
            COMPUTE_SIGNATURE: begin
                if (neighbor_index == 3'd7)
                    next_state = NEXT_ROOM;
                else
                    next_state = COMPUTE_SIGNATURE;
            end
            NEXT_ROOM: begin
                if (current_room == 3'd7)
                    next_state = DONE_STATE;
                else
                    next_state = COMPUTE_SIGNATURE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_room <= 3'd0;
            neighbor_index <= 3'd0;
            temp_signature <= 32'd0;
            neighbor_degree_sum <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all signatures
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                signature[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                RESET: begin
                    current_room <= 3'd0;
                    neighbor_index <= 3'd0;
                    neighbor_degree_sum <= 4'd0;
                    cycle_count <= cycle_count + 8'd1;
                end
                COMPUTE_SIGNATURE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current neighbor is connected
                    if (adj[current_room][neighbor_index]) begin
                        neighbor_degree_sum <= neighbor_degree_sum + degree[neighbor_index];
                    end
                    
                    // Move to next neighbor
                    if (neighbor_index == 3'd7) begin
                        // Compute final signature
                        temp_signature <= degree[current_room] + (neighbor_degree_sum << 4);
                        signature[current_room] <= temp_signature[31:0];
                        
                        // Reset for next room
                        neighbor_degree_sum <= 4'd0;
                    end else begin
                        neighbor_index <= neighbor_index + 3'd1;
                    end
                end
                NEXT_ROOM: begin
                    current_room <= current_room + 3'd1;
                    neighbor_index <= 3'd0;
                    
                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule