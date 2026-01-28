module polynomial_differentiation (
    input clk,
    input rst_n,
    input start,
    input [7:0] coeff [0:15],
    input [3:0] len,
    output reg [11:0] result [0:15],
    output reg done,
    output reg [3:0] result_len
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTE   = 2'd1;
    localparam [1:0] COMPLETE  = 2'd2;

    // Registers and wires
    reg [1:0] state, next_state;
    reg [3:0] idx, next_idx;
    reg [3:0] max_idx, next_max_idx;
    reg [7:0] coeff_reg [0:15];
    reg [7:0] next_coeff_reg [0:15];
    
    integer i;
    
    // Sequential state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            max_idx <= 4'd0;
            done <= 1'b0;
            result_len <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 12'sd0;
                coeff_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            idx <= next_idx;
            max_idx <= next_max_idx;
            done <= (state == COMPLETE);
            result_len <= (len > 1) ? (len - 1) : 4'd0;
            
            // Update coefficient register in COMPUTE state
            if (state == COMPUTE) begin
                coeff_reg <= next_coeff_reg;
            end
            
            // Update results (accumulated during iteration)
            if (state == COMPUTE && idx > 0) begin
                result[idx - 1] <= coeff_reg[idx] * idx;
            end
            
            // Clear outputs when returning to IDLE
            if (state == IDLE && next_state != IDLE) begin
                for (i = 0; i < 16; i = i + 1) begin
                    result[i] <= 12'sd0;
                end
                result_len <= 4'd0;
            end
        end
    end

    // Combinational next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_idx = idx;
        next_max_idx = max_idx;
        
        // Default coefficient register pass-through
        for (i = 0; i < 16; i = i + 1) begin
            next_coeff_reg[i] = coeff_reg[i];
        end
        
        case (state)
            IDLE: begin
                done = 1'b0;
                next_idx = 4'd0;
                if (start) begin
                    next_state = COMPUTE;
                    next_max_idx = len;
                    // Load coefficients into register
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < len) begin
                            next_coeff_reg[i] = coeff[i];
                        end else begin
                            next_coeff_reg[i] = 8'd0;
                        end
                    end
                end
            end
            
            COMPUTE: begin
                if (idx < max_idx) begin
                    next_idx = idx + 1;
                    // Done with iteration
                    if (idx + 1 == max_idx) begin
                        next_state = COMPLETE;
                    end
                end else begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule