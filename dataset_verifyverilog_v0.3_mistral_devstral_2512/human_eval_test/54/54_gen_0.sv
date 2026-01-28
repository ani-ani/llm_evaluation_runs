module same_chars(
    input clk,
    input rst_n,
    input start,
    input [7:0] s0 [0:7],
    input [7:0] s1 [0:7],
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SETUP     = 3'd1;
    localparam [2:0] PROCESS_0 = 3'd2;
    localparam [2:0] PROCESS_1 = 3'd3;
    localparam [2:0] COMPARE   = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // State register
    reg [2:0] state, next_state;

    // Character presence masks (256 bits each, packed as 8x32)
    reg [31:0] mask0 [0:7];
    reg [31:0] mask1 [0:7];

    // Counters
    reg [2:0] char_idx;  // 0-7 for string iteration
    reg [7:0] bit_idx;   // 0-255 for mask comparison
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            char_idx <= 3'd0;
            bit_idx <= 8'd0;
            cycle_count <= 8'd0;
            
            // Initialize masks
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                mask0[i] <= 32'd0;
                mask1[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                end else begin
                    next_state = IDLE;
                end
            end
            
            SETUP: begin
                next_state = PROCESS_0;
            end
            
            PROCESS_0: begin
                if (char_idx == 3'd7) begin
                    next_state = PROCESS_1;
                end else begin
                    next_state = PROCESS_0;
                end
            end
            
            PROCESS_1: begin
                if (char_idx == 3'd7) begin
                    next_state = COMPARE;
                end else begin
                    next_state = PROCESS_1;
                end
            end
            
            COMPARE: begin
                if (bit_idx == 8'd255) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Character processing for s0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_idx <= 3'd0;
        end else if (state == PROCESS_0) begin
            // Set corresponding bit in mask0
            reg [7:0] char = s0[char_idx];
            reg [7:0] byte_idx = char[7:3];
            reg [4:0] bit_pos = char[2:0];
            
            mask0[byte_idx] <= mask0[byte_idx] | (1 << bit_pos);
            
            if (char_idx == 3'd7) begin
                char_idx <= 3'd0;
            end else begin
                char_idx <= char_idx + 3'd1;
            end
        end
    end

    // Character processing for s1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_idx <= 3'd0;
        end else if (state == PROCESS_1) begin
            // Set corresponding bit in mask1
            reg [7:0] char = s1[char_idx];
            reg [7:0] byte_idx = char[7:3];
            reg [4:0] bit_pos = char[2:0];
            
            mask1[byte_idx] <= mask1[byte_idx] | (1 << bit_pos);
            
            if (char_idx == 3'd7) begin
                char_idx <= 3'd0;
            end else begin
                char_idx <= char_idx + 3'd1;
            end
        end
    end

    // Mask comparison
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_idx <= 8'd0;
            result <= 1'b0;
        end else if (state == COMPARE) begin
            reg [7:0] byte_idx = bit_idx[7:3];
            reg [4:0] bit_pos = bit_idx[2:0];
            
            if (mask0[byte_idx][bit_pos] != mask1[byte_idx][bit_pos]) begin
                result <= 1'b0;
            end
            
            if (bit_idx == 8'd255) begin
                result <= 1'b1;
                bit_idx <= 8'd0;
            end else begin
                bit_idx <= bit_idx + 8'd1;
            end
        end
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                SETUP: begin
                    cycle_count <= cycle_count + 8'd1;
                    done <= 1'b0;
                end
                
                PROCESS_0: begin
                    cycle_count <= cycle_count + 8'd1;
                    done <= 1'b0;
                end
                
                PROCESS_1: begin
                    cycle_count <= cycle_count + 8'd1;
                    done <= 1'b0;
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    done <= 1'b0;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    cycle_count <= 8'd0;
                end
                
                default: done <= 1'b0;
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
                cycle_count <= 8'd0;
            end
        end
    end

endmodule