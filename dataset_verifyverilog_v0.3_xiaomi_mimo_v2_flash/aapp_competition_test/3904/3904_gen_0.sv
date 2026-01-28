module bracket_sequence(
    input clk,
    input rst_n,
    input start,
    input [15:0] string_bits,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT_OPEN_CLOSE = 3'd1;
    localparam [2:0] CHECK_COUNTS = 3'd2;
    localparam [2:0] COMPUTE_COST = 3'd3;
    localparam [2:0] DONE = 3'd4;
    localparam [2:0] WAIT_DONE = 3'd5;
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i;
    reg [4:0] open_count;
    reg [4:0] close_count;
    reg signed [5:0] balance;
    reg signed [5:0] balance_next;
    reg in_segment;
    reg [3:0] start_reg;
    reg [5:0] cost;
    reg [4:0] seg_len;
    reg [3:0] cycle_count;
    
    // Combinational logic for balance update
    always @(*) begin
        if (string_bits[i] == 1'b1) begin
            balance_next = balance + 1'sd1;
        end else begin
            balance_next = balance - 1'sd1;
        end
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            open_count <= 5'd0;
            close_count <= 5'd0;
            balance <= 6'sd0;
            in_segment <= 1'b0;
            start_reg <= 4'd0;
            cost <= 6'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            seg_len <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= COUNT_OPEN_CLOSE;
                        i <= 4'd0;
                        open_count <= 5'd0;
                        close_count <= 5'd0;
                    end
                end
                
                COUNT_OPEN_CLOSE: begin
                    if (string_bits[i] == 1'b1) begin
                        open_count <= open_count + 5'd1;
                    end else begin
                        close_count <= close_count + 5'd1;
                    end
                    
                    if (i == 4'd15) begin
                        state <= CHECK_COUNTS;
                        i <= 4'd0;
                    end else begin
                        i <= i + 4'd1;
                    end
                end
                
                CHECK_COUNTS: begin
                    if (open_count != close_count) begin
                        result <= 16'hFFFF;
                        state <= WAIT_DONE;
                    end else begin
                        state <= COMPUTE_COST;
                        i <= 4'd0;
                        balance <= 6'sd0;
                        in_segment <= 1'b0;
                        start_reg <= 4'd0;
                        cost <= 6'd0;
                        seg_len <= 5'd0;
                    end
                end
                
                COMPUTE_COST: begin
                    balance <= balance_next;
                    
                    if (balance_next < 6'sd0 && in_segment == 1'b0) begin
                        in_segment <= 1'b1;
                        start_reg <= i;
                        seg_len <= 5'd0;
                    end
                    
                    if (in_segment == 1'b1) begin
                        seg_len <= seg_len + 5'd1;
                    end
                    
                    if (balance_next == 6'sd0 && in_segment == 1'b1) begin
                        cost <= cost + seg_len;
                        in_segment <= 1'b0;
                    end
                    
                    if (i == 4'd15) begin
                        state <= WAIT_DONE;
                    end else begin
                        i <= i + 4'd1;
                    end
                end
                
                WAIT_DONE: begin
                    done <= 1'b1;
                    if (cost < 6'd16) begin
                        result <= cost;
                    end else begin
                        result <= 16'd0;
                    end
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    i <= 4'd0;
                    open_count <= 5'd0;
                    close_count <= 5'd0;
                    balance <= 6'sd0;
                    in_segment <= 1'b0;
                    start_reg <= 4'd0;
                    cost <= 6'd0;
                    result <= 16'd0;
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    seg_len <= 5'd0;
                end
            endcase
        end
    end
endmodule