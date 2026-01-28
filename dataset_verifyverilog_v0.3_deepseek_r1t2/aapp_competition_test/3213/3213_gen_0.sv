module spell_optimizer #(
    parameter M = 8,
    parameter S = 4
)(
    input clk,
    input rst_n,
    input start,
    input [7:0] steps [0:M-1],
    output reg [7:0] result [0:M-1],
    output reg done
);

// State definitions
localparam [2:0] STATE_IDLE         = 3'd0;
localparam [2:0] STATE_EVAL_INIT    = 3'd1;
localparam [2:0] STATE_EVAL_LOOP    = 3'd2;
localparam [2:0] STATE_EVAL_DONE    = 3'd3;
localparam [2:0] STATE_NEXT_MASK    = 3'd4;
localparam [2:0] STATE_CONVERT      = 3'd5;
localparam [2:0] STATE_DONE         = 3'd6;

// Registers
reg [2:0] state;
reg [M-1:0] mask_reg;
reg [2:0] idx_reg;
reg [S-1:0] val_reg;
reg [S-1:0] best_val_reg;
reg [M-1:0] best_mask_reg;
reg [7:0] steps_reg [0:M-1];
reg [2:0] convert_idx;
reg [7:0] cycle_count;

// Combinational logic
wire [S-1:0] next_val_add = (val_reg + 1'd1) & {S{1'b1}};
wire [S-1:0] next_val_mul = (val_reg << 1) & {S{1'b1}};

// Array initialization integer
genvar i;
integer idx;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        mask_reg <= {M{1'b0}};
        idx_reg <= 3'd0;
        val_reg <= {S{1'b0}};
        best_val_reg <= {S{1'b0}};
        best_mask_reg <= {M{1'b0}};
        convert_idx <= 3'd0;
        cycle_count <= 8'd0;
        done <= 1'b0;
        
        // Initialize arrays
        for (idx = 0; idx < M; idx = idx + 1) begin
            steps_reg[idx] <= 8'h00;
            result[idx] <= 8'h00;
        end
    end else begin
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            // IDLE STATE
            STATE_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Copy input steps
                    for (idx = 0; idx < M; idx = idx + 1) begin
                        steps_reg[idx] <= steps[idx];
                    end
                    mask_reg <= {M{1'b0}};
                    best_val_reg <= {S{1'b0}};
                    best_mask_reg <= {M{1'b0}};
                    state <= STATE_EVAL_INIT;
                end
            end
            
            // EVALUATION INIT
            STATE_EVAL_INIT: begin
                val_reg <= {{(S-1){1'b0}}, 1'b1}; // Start at 1
                idx_reg <= 3'd0;
                state <= STATE_EVAL_LOOP;
            end
            
            // EVALUATION LOOP
            STATE_EVAL_LOOP: begin
                if (idx_reg < 3'd7) begin // M-1 (7) because M=8
                    if (mask_reg[idx_reg]) begin
                        case (steps_reg[idx_reg])
                            8'h2B: val_reg <= next_val_add; // '+'
                            8'h78: val_reg <= next_val_mul; // 'x'
                            default: val_reg <= val_reg;
                        endcase
                    end
                    idx_reg <= idx_reg + 3'd1;
                end else begin
                    state <= STATE_EVAL_DONE;
                end
            end
            
            // EVALUATION DONE
            STATE_EVAL_DONE: begin
                if (val_reg > best_val_reg) begin
                    best_val_reg <= val_reg;
                    best_mask_reg <= mask_reg;
                end
                state <= STATE_NEXT_MASK;
            end
            
            // NEXT MASK STATE
            STATE_NEXT_MASK: begin
                mask_reg <= mask_reg + 1'b1;
                // Check all 256 masks (2^8)
                if (&mask_reg) begin
                    state <= STATE_CONVERT;
                    convert_idx <= 3'd0;
                end else begin
                    state <= STATE_EVAL_INIT;
                end
            end
            
            // CONVERT OUTPUT
            STATE_CONVERT: begin
                if (convert_idx < 3'd7) begin // M-1 (7)
                    result[convert_idx] <= best_mask_reg[convert_idx] ? 
                                          steps_reg[convert_idx] : 
                                          8'h6F; // 'o'
                    convert_idx <= convert_idx + 3'd1;
                end else begin
                    state <= STATE_DONE;
                    done <= 1'b1;
                end
            end
            
            // FINAL DONE
            STATE_DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= STATE_IDLE;
                end
            end
            
            default: state <= STATE_IDLE;
        endcase
    end
end

endmodule