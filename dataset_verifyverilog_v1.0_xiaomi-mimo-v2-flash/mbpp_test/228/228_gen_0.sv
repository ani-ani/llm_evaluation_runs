module CheckBitsInRange (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [3:0] l,
    input wire [3:0] r,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [15:0] mask_reg;
    reg [15:0] n_reg;
    reg [3:0] l_reg;
    reg [3:0] r_reg;
    reg computation_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            mask_reg <= 16'd0;
            n_reg <= 16'd0;
            l_reg <= 4'd0;
            r_reg <= 4'd0;
            computation_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        n_reg <= n;
                        l_reg <= (l == 4'd0) ? 4'd1 : l;  // Handle l=0 case
                        r_reg <= r;
                        computation_done <= 1'b0;
                    end
                end

                COMPUTE: begin
                    // Compute mask: ((1 << r) - 1) ^ ((1 << (l-1)) - 1)
                    // l_reg and r_reg are already adjusted (1-indexed, 1-16)
                    // Convert to 0-indexed for bit positions: l_pos = l-1, r_pos = r-1
                    // Bits to check: from (l-1) to (r-1) inclusive
                    // But since l and r are 1-indexed, we check bits (l-1) to (r-1)
                    // For example, l=1,r=1 => check bit 0
                    // ((1<<1)-1) ^ ((1<<0)-1) = (2-1) ^ (1-1) = 1 ^ 0 = 1
                    // Which is 1'b1, correct for bit 0
                    // l=1,r=16 => check bits 0-15
                    // ((1<<16)-1) ^ ((1<<0)-1) = 0xFFFF ^ 0 = 0xFFFF
                    
                    // Compute right bound mask: (1 << r_reg) - 1
                    // Compute left bound mask: (1 << (l_reg - 1)) - 1
                    // Result mask: right_mask ^ left_mask
                    
                    // Note: Since r can be 16, 1<<r_reg needs 17 bits
                    // But result fits in 16 bits when r=16
                    
                    // For l=1, r=16: check bits 0-15 (all bits)
                    // right_mask = (1<<16)-1 = 0xFFFF
                    // left_mask = (1<<0)-1 = 0
                    // mask = 0xFFFF ^ 0 = 0xFFFF
                    
                    // For l=1, r=1: check bit 0 only
                    // right_mask = (1<<1)-1 = 1
                    // left_mask = (1<<0)-1 = 0
                    // mask = 1 ^ 0 = 1
                    
                    // For l=4, r=6: check bits 3-5
                    // right_mask = (1<<6)-1 = 0x3F (bits 0-5)
                    // left_mask = (1<<3)-1 = 0x07 (bits 0-2)
                    // mask = 0x3F ^ 0x07 = 0x38 (bits 3-5)
                    
                    // Use combinational logic
                    computation_done <= 1'b1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                    computation_done <= 1'b0;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for mask calculation and result
    reg [15:0] right_mask;
    reg [15:0] left_mask;
    reg [15:0] mask;
    
    always @(*) begin
        // Default values
        right_mask = 16'd0;
        left_mask = 16'd0;
        mask = 16'd0;
        
        // Calculate right mask: (1 << r_reg) - 1
        // r_reg is 1-16, so we need to shift by r_reg bits
        // When r_reg = 16, we want 0xFFFF
        // (1 << 16) = 0x10000, minus 1 = 0xFFFF
        // But we only need 16 bits, so we handle the case
        
        case (r_reg)
            4'd1: right_mask = 16'h0001;
            4'd2: right_mask = 16'h0003;
            4'd3: right_mask = 16'h0007;
            4'd4: right_mask = 16'h000F;
            4'd5: right_mask = 16'h001F;
            4'd6: right_mask = 16'h003F;
            4'd7: right_mask = 16'h007F;
            4'd8: right_mask = 16'h00FF;
            4'd9: right_mask = 16'h01FF;
            4'd10: right_mask = 16'h03FF;
            4'd11: right_mask = 16'h07FF;
            4'd12: right_mask = 16'h0FFF;
            4'd13: right_mask = 16'h1FFF;
            4'd14: right_mask = 16'h3FFF;
            4'd15: right_mask = 16'h7FFF;
            4'd16: right_mask = 16'hFFFF;
            default: right_mask = 16'd0;
        endcase
        
        // Calculate left mask: (1 << (l_reg - 1)) - 1
        // l_reg is 1-16, so l_reg-1 is 0-15
        case (l_reg - 4'd1)
            4'd0: left_mask = 16'h0000;
            4'd1: left_mask = 16'h0001;
            4'd2: left_mask = 16'h0003;
            4'd3: left_mask = 16'h0007;
            4'd4: left_mask = 16'h000F;
            4'd5: left_mask = 16'h001F;
            4'd6: left_mask = 16'h003F;
            4'd7: left_mask = 16'h007F;
            4'd8: left_mask = 16'h00FF;
            4'd9: left_mask = 16'h01FF;
            4'd10: left_mask = 16'h03FF;
            4'd11: left_mask = 16'h07FF;
            4'd12: left_mask = 16'h0FFF;
            4'd13: left_mask = 16'h1FFF;
            4'd14: left_mask = 16'h3FFF;
            4'd15: left_mask = 16'h7FFF;
            default: left_mask = 16'd0;
        endcase
        
        // Mask = right_mask ^ left_mask
        mask = right_mask ^ left_mask;
    end
    
    // Result calculation: check if (n_reg & mask) == 0
    always @(*) begin
        if (computation_done && (state == COMPUTE || state == FINISH)) begin
            result = ((n_reg & mask) == 16'd0) ? 1'b1 : 1'b0;
        end else begin
            result = 1'b0;
        end
    end

endmodule