module simple_hash(
    input clk,
    input rst_n,
    input start,
    input [7:0] chars [0:7],
    input [7:0] length,
    output reg [31:0] hash,
    output reg done,
    output reg is_empty
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Counter for character processing
    reg [2:0] i;
    reg [2:0] next_i;
    
    // Internal hash register
    reg [31:0] hash_reg;
    reg [31:0] next_hash;
    
    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 3'd0;
            hash_reg <= 32'd0;
            hash <= 32'd0;
            done <= 1'b0;
            is_empty <= 1'b0;
        end else begin
            state <= next_state;
            i <= next_i;
            hash_reg <= next_hash;
        end
    end
    
    // Next state and output logic
    always @(*) begin
        next_state = state;
        next_i = i;
        next_hash = hash_reg;
        done = 1'b0;
        is_empty = 1'b0;
        hash = hash_reg;
        
        case (state)
            IDLE: begin
                if (start) begin
                    if (length == 8'd0) begin
                        is_empty = 1'b1;
                        next_state = FINISH;
                    end else begin
                        next_state = PROCESS;
                        next_i = 3'd0;
                        next_hash = 32'd0;
                    end
                end
            end
            
            PROCESS: begin
                if (i < length) begin
                    next_hash = (hash_reg << 5) + hash_reg + chars[i];
                    next_i = i + 3'd1;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_i = 3'd0;
                next_hash = 32'd0;
            end
        endcase
    end
endmodule