module phaser_opt #(
    parameter MAX_ROOMS = 8,
    parameter COORD_BITS = 10,  // Coordinates 0-1000
    parameter L_BITS = 10,      // Length 0-1000
    parameter DATA_WIDTH = COORD_BITS,
    parameter ARRAY_SIZE = 4*MAX_ROOMS + 1
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr [0:ARRAY_SIZE-1],
    input wire [3:0] num_rooms,
    output reg [7:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] INIT      = 3'd2;
    localparam [2:0] LOOP_I    = 3'd3;
    localparam [2:0] LOOP_J    = 3'd4;
    localparam [2:0] COMPUTE   = 3'd5;
    localparam [2:0] UPDATE_MAX= 3'd6;
    localparam [2:0] DONE_STATE= 3'd7;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [COORD_BITS-1:0] coords [0:4*MAX_ROOMS-1];
    reg [L_BITS-1:0] ell;
    reg [5:0] i, j;
    reg [7:0] max_hit, current_hit;
    reg [5:0] room_idx;
    reg [15:0] cycle_count; // Prevent infinite loops
    
    // Fixed-point (Q8.8) signals
    reg signed [15:0] x1, y1, x2, y2, dx, dy, step_x, step_y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            max_hit <= 8'd0;
            current_hit <= 8'd0;
            i <= 6'd0;
            j <= 6'd0;
            cycle_count <= 16'd0;
            // Initialize coordinate array
            for (room_idx = 0; room_idx < 4*MAX_ROOMS; room_idx = room_idx + 1) begin
                coords[room_idx] <= {COORD_BITS{1'b0}};
            end
        end
        else begin
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    cycle_count <= 16'd0;
                    if (start) state <= LOAD;
                end
                
                LOAD: begin
                    for (room_idx = 0; room_idx < 4*num_rooms; room_idx = room_idx + 1) begin
                        coords[room_idx] <= arr[room_idx];
                    end
                    ell <= arr[4*num_rooms];
                    state <= INIT;
                end
                
                INIT: begin
                    i <= 6'd0;
                    j <= 6'd0;
                    max_hit <= 8'd0;
                    state <= LOOP_I;
                end
                
                LOOP_I: begin
                    if (i < 4*num_rooms) begin
                        j <= 6'd0;
                        state <= LOOP_J;
                    end
                    else begin
                        state <= DONE_STATE;
                    end
                end
                
                LOOP_J: begin
                    if (j < 4*num_rooms) begin
                        if (i != j) begin
                            x1 <= {coords[i], 8'd0}; // Convert to Q8.8
                            y1 <= {coords[i+1], 8'd0};
                            x2 <= {coords[j], 8'd0};
                            y2 <= {coords[j+1], 8'd0};
                            state <= COMPUTE;
                        end
                        else begin
                            j <= j + 6'd1;
                        end
                    end
                    else begin
                        i <= i + 6'd1;
                        state <= LOOP_I;
                    end
                end
                
                COMPUTE: begin
                    // Simplified computation placeholder
                    // Actual implementation requires Liang-Barsky/edge checks
                    dx <= x2 - x1;
                    dy <= y2 - y1;
                    
                    // Normalization would happen here
                    // For now: count some rooms hit
                    current_hit <= 8'd2; 
                    
                    state <= UPDATE_MAX;
                end
                
                UPDATE_MAX: begin
                    if (current_hit > max_hit) max_hit <= current_hit;
                    j <= j + 6'd1;
                    state <= LOOP_J;
                end
                
                DONE_STATE: begin
                    result <= max_hit;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            if (cycle_count > 16'd10000) state <= DONE_STATE; // Safety timeout
        end
    end
endmodule