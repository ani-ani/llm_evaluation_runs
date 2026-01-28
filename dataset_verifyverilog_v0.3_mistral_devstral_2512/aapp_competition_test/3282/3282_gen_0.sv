module dessert_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] P,
    
    output reg [15:0] count,
    output reg [15:0] beverage,
    output reg [15:0] main_dish,
    output reg pair_valid,
    output reg done
);

// State encoding
localparam [1:0] IDLE = 2'd0;
localparam [1:0] INIT = 2'd1;
localparam [1:0] CHECK = 2'd2;
localparam [1:0] DONE = 2'd3;

// Registers
reg [1:0] state, next_state;
reg [15:0] b, next_b;
reg [15:0] count_reg, next_count;
reg [15:0] beverage_reg, next_beverage;
reg [15:0] main_dish_reg, next_main_dish;
reg pair_valid_reg, next_pair_valid;
reg done_reg, next_done;

// Combinational logic
wire [15:0] m;
wire [9:0] mask_b, mask_m, mask_P;
wire disjoint;

assign m = P - b;

// Digit mask computation function
function [9:0] compute_mask;
    input [15:0] num;
    reg [3:0] digit;
    begin
        compute_mask = 10'd0;
        digit = num % 10;
        compute_mask[digit] = 1'b1;
        if (num >= 10) begin
            digit = (num / 10) % 10;
            compute_mask[digit] = 1'b1;
        end
        if (num >= 100) begin
            digit = (num / 100) % 10;
            compute_mask[digit] = 1'b1;
        end
        if (num >= 1000) begin
            digit = (num / 1000) % 10;
            compute_mask[digit] = 1'b1;
        end
        if (num >= 10000) begin
            digit = (num / 10000) % 10;
            compute_mask[digit] = 1'b1;
        end
    end
endfunction

assign mask_b = compute_mask(b);
assign mask_m = compute_mask(m);
assign mask_P = compute_mask(P);

assign disjoint = ((mask_b & mask_m) == 10'd0) && 
                  ((mask_b & mask_P) == 10'd0) && 
                  ((mask_m & mask_P) == 10'd0);

// State machine
always @(*) begin
    next_state = state;
    next_b = b;
    next_count = count_reg;
    next_beverage = beverage_reg;
    next_main_dish = main_dish_reg;
    next_pair_valid = 1'b0;
    next_done = 1'b0;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT;
            end
        end
        
        INIT: begin
            next_b = 16'd1;
            next_count = 16'd0;
            next_state = CHECK;
        end
        
        CHECK: begin
            if (b < (P - b)) begin
                if (disjoint) begin
                    next_beverage = b;
                    next_main_dish = m;
                    next_count = count_reg + 1;
                    next_pair_valid = 1'b1;
                end
                if (b < P - 16'd1) begin
                    next_b = b + 1;
                    next_state = CHECK;
                end else begin
                    next_state = DONE;
                end
            end else begin
                next_state = DONE;
            end
        end
        
        DONE: begin
            next_done = 1'b1;
            if (~start) begin
                next_state = IDLE;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        b <= 16'd0;
        count_reg <= 16'd0;
        beverage_reg <= 16'd0;
        main_dish_reg <= 16'd0;
        pair_valid_reg <= 1'b0;
        done_reg <= 1'b0;
    end else begin
        state <= next_state;
        b <= next_b;
        count_reg <= next_count;
        beverage_reg <= next_beverage;
        main_dish_reg <= next_main_dish;
        pair_valid_reg <= next_pair_valid;
        done_reg <= next_done;
    end
end

// Output assignments
always @(*) begin
    count = count_reg;
    beverage = beverage_reg;
    main_dish = main_dish_reg;
    pair_valid = pair_valid_reg;
    done = done_reg;
end

endmodule