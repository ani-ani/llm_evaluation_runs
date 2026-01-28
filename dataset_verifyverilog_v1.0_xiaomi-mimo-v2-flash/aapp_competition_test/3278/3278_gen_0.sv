module frog_tower(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] frog_pos [0:7],
    input wire [4:0] frog_dist [0:7],
    input wire [3:0] num_frogs,
    output reg [15:0] result_pos,
    output reg [3:0] result_size,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] SCAN_INIT   = 3'd1;
    localparam [2:0] SCAN_CHECK  = 3'd2;
    localparam [2:0] SCAN_COUNT  = 3'd3;
    localparam [2:0] COMPARE     = 3'd4;
    localparam [2:0] CHECK_LIMIT = 3'd5;
    localparam [2:0] DONE        = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] pos;              // Current position being checked
    reg [15:0] best_pos;         // Best position found
    reg [3:0] max_count;         // Maximum frogs found so far
    reg [3:0] current_count;     // Count for current position
    reg [3:0] frog_idx;          // Current frog index (0-7)
    reg [15:0] pos_reg;          // Registered copy for calculations
    reg [4:0] dist_reg;          // Registered copy for calculations
    reg [7:0] temp_pos;          // Temporary position storage
    reg [3:0] limit_counter;     // Counter for scan limit (0-16)
    
    // Combinational logic for modulo check
    wire [15:0] diff;
    wire [15:0] div_result;
    wire [4:0] mod_result;
    wire can_reach;
    
    assign diff = pos_reg - temp_pos;
    assign div_result = diff / dist_reg;
    assign mod_result = diff - (div_result * dist_reg);
    assign can_reach = (pos_reg >= temp_pos) && (mod_result == 0) && (frog_idx < num_frogs);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_pos <= 16'd0;
            result_size <= 4'd0;
            done <= 1'b0;
            pos <= 16'd0;
            best_pos <= 16'd0;
            max_count <= 4'd0;
            current_count <= 4'd0;
            frog_idx <= 4'd0;
            pos_reg <= 16'd0;
            dist_reg <= 5'd0;
            temp_pos <= 8'd0;
            limit_counter <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    pos <= 16'd0;
                    best_pos <= 16'd0;
                    max_count <= 4'd0;
                end
                
                SCAN_INIT: begin
                    current_count <= 4'd0;
                    frog_idx <= 4'd0;
                    pos_reg <= pos;
                end
                
                SCAN_CHECK: begin
                    if (frog_idx < num_frogs) begin
                        temp_pos <= frog_pos[frog_idx];
                        dist_reg <= frog_dist[frog_idx];
                    end
                end
                
                SCAN_COUNT: begin
                    if (can_reach) begin
                        current_count <= current_count + 4'd1;
                    end
                    frog_idx <= frog_idx + 4'd1;
                end
                
                COMPARE: begin
                    if (current_count > max_count) begin
                        max_count <= current_count;
                        best_pos <= pos;
                    end
                end
                
                CHECK_LIMIT: begin
                    pos <= pos + 16'd1;
                    limit_counter <= limit_counter + 4'd1;
                end
                
                DONE: begin
                    result_pos <= best_pos;
                    result_size <= max_count;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN_INIT;
                else
                    next_state = IDLE;
            end
            
            SCAN_INIT: begin
                if (num_frogs == 4'd0)
                    next_state = DONE;
                else
                    next_state = SCAN_CHECK;
            end
            
            SCAN_CHECK: begin
                if (frog_idx < num_frogs)
                    next_state = SCAN_COUNT;
                else
                    next_state = COMPARE;
            end
            
            SCAN_COUNT: begin
                next_state = SCAN_CHECK;
            end
            
            COMPARE: begin
                next_state = CHECK_LIMIT;
            end
            
            CHECK_LIMIT: begin
                if (limit_counter >= 4'd8)  // Scan up to 256 positions (8 bits)
                    next_state = DONE;
                else
                    next_state = SCAN_INIT;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule