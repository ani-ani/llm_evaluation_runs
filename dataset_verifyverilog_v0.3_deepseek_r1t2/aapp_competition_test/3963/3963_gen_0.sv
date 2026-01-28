module coin_change (
    input wire clk,
    input wire rst_n,
    input wire start,
    input [2:0] n,
    input [31:0] a [0:7],
    input [15:0] b [0:7],
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

localparam MOD_VAL = 32'd1000000007;

// State definitions
localparam [2:0] IDLE      = 3'd0;
localparam [2:0] INIT      = 3'd1;
localparam [2:0] COMPUTE   = 3'd2;
localparam [2:0] NEXT_COIN = 3'd3;
localparam [2:0] FINISH    = 3'd4;

// Internal signals
reg [2:0] state, next_state;
reg [2:0] coin_idx;
reg [31:0] denom, next_denom;
reg [31:0] dp_current [0:1023]; // Up to 1024 states
reg [31:0] dp_next [0:1023];
reg [9:0] r_index; // Supports up to 1024 states
reg [15:0] c_count;
reg dp_initialized;
reg [15:0] cycle_count;
integer i;

// FSM logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        denom <= 32'd1;
        cycle_count <= 16'd0;
        coin_idx <= 3'd0;
        
        for (i = 0; i < 1024; i = i + 1) begin
            dp_current[i] <= 32'd0;
            dp_next[i] <= 32'd0;
        end
    end
    else begin
        cycle_count <= cycle_count + 16'd1;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT;
                    cycle_count <= 16'd0;
                end
            end
            
            INIT: begin
                denom <= 32'd1;
                coin_idx <= 3'd0;
                
                // Initialize dp_current
                for (i = 0; i < 1024; i = i + 1) begin
                    dp_current[i] <= 32'd0;
                end
                dp_current[0] <= 32'd1;
                
                // Calculate next_denom
                if (3'd0 < (n - 3'd1)) begin
                    next_denom <= denom * a[0];
                end
                else begin
                    next_denom <= denom;
                end
                
                state <= COMPUTE;
                r_index <= 10'd0;
                c_count <= 16'd0;
                dp_initialized <= 1'b0;
            end
            
            COMPUTE: begin
                if (dp_initialized == 1'b0) begin
                    // Initialize dp_next
                    for (i = 0; i < 1024; i = i + 1) begin
                        dp_next[i] <= 32'd0;
                    end
                    dp_initialized <= 1'b1;
                    r_index <= 10'd0;
                    c_count <= 16'd0;
                end
                else begin
                    if (r_index < denom && denom <= 1024) begin // Stay within array bounds
                        if (c_count <= b[coin_idx]) begin
                            // Current computation
                            if ((r_index + c_count * denom) < next_denom) begin
                                dp_next[r_index + c_count * denom] <= (dp_next[r_index + c_count * denom] + dp_current[r_index]) % MOD_VAL;
                            end
                            c_count <= c_count + 16'd1;
                        end
                        else begin
                            c_count <= 16'd0;
                            r_index <= r_index + 10'd1;
                        end
                    end
                    else begin
                        state <= NEXT_COIN;
                    end
                end
            end
            
            NEXT_COIN: begin
                // Copy dp_next to dp_current
                for (i = 0; i < 1024; i = i + 1) begin
                    dp_current[i] <= dp_next[i];
                end
                
                denom <= next_denom;
                coin_idx <= coin_idx + 3'd1;
                
                if (coin_idx < (n - 3'd1)) begin
                    // Calculate next_denom
                    if (coin_idx + 1 < (n - 3'd1)) begin
                        next_denom <= denom * a[coin_idx + 1];
                    end
                    else begin
                        next_denom <= denom;
                    end
                    
                    state <= COMPUTE;
                    r_index <= 10'd0;
                    c_count <= 16'd0;
                    dp_initialized <= 1'b0;
                end
                else begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                if (denom != 32'd0) begin
                    result <= dp_current[m % denom] % MOD_VAL;
                end
                else begin
                    result <= 32'd0;
                end
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule
