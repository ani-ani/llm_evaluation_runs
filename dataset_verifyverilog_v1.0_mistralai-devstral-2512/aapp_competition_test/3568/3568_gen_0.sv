module floppy_organ(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] t_i,
    input wire [6:0] n_intervals,
    input wire [15:0] interval_start [0:127],
    input wire [15:0] interval_end [0:127],
    input wire interval_valid [0:127],
    output reg result,
    output reg done,
    output reg [1:0] status
);

    // Parameters
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT_MASK = 2'd1;
    localparam [1:0] PROCESS_INTERVAL = 2'd2;
    localparam [1:0] CHECK_LAST = 2'd3;
    localparam [1:0] DONE_STATE = 2'd4;
    
    localparam [13:0] MAX_MASK_BITS = 14'd10001;
    
    // State
    reg [1:0] state;
    reg [6:0] current_interval;
    reg [13:0] pos;
    reg [15:0] gap;
    reg [15:0] L_next;
    reg [15:0] time_remaining;
    
    // Mask storage (using a register array for synthesis)
    reg [13:0] mask_out_end [0:10000];
    reg [13:0] mask_in_end [0:10000];
    reg [13:0] mask_current_out [0:10000];
    reg [13:0] mask_current_in [0:10000];
    reg [13:0] mask_next_out_end [0:10000];
    reg [13:0] mask_next_in_end [0:10000];
    
    // Prefix sum arrays
    reg [15:0] prefix_out [0:10000];
    reg [15:0] prefix_in [0:10000];
    
    // Internal signals
    reg [15:0] shift_limit;
    reg [15:0] p;
    reg [15:0] q;
    reg [15:0] dist;
    reg direction_cost;
    reg [15:0] total_time;
    reg [15:0] valid_out_start_low;
    reg [15:0] valid_out_start_high;
    reg [15:0] valid_in_start_low;
    reg [15:0] valid_in_start_high;
    
    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_interval <= 7'd0;
            pos <= 14'd0;
            gap <= 16'd0;
            L_next <= 16'd0;
            time_remaining <= 16'd0;
            result <= 1'b0;
            done <= 1'b0;
            status <= 2'd0;
            
            // Initialize masks
            for (p = 0; p < MAX_MASK_BITS; p = p + 1) begin
                mask_out_end[p] <= 14'd0;
                mask_in_end[p] <= 14'd0;
                mask_current_out[p] <= 14'd0;
                mask_current_in[p] <= 14'd0;
                mask_next_out_end[p] <= 14'd0;
                mask_next_in_end[p] <= 14'd0;
                prefix_out[p] <= 16'd0;
                prefix_in[p] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT_MASK;
                        current_interval <= 7'd0;
                    end
                end
                
                INIT_MASK: begin
                    // Compute initial masks for interval 0
                    L_next <= interval_end[0] - interval_start[0];
                    
                    // Check if L_next > t_i
                    if (L_next > t_i) begin
                        state <= DONE_STATE;
                        result <= 1'b0;
                        status <= 2'd2;
                    end else begin
                        // Set mask_out_end: positions L_next to t_i
                        for (p = 0; p < MAX_MASK_BITS; p = p + 1) begin
                            if (p >= L_next && p <= t_i) begin
                                mask_out_end[p] <= 14'd1;
                            end else begin
                                mask_out_end[p] <= 14'd0;
                            end
                        end
                        
                        // Set mask_in_end: positions 0 to t_i - L_next
                        for (p = 0; p < MAX_MASK_BITS; p = p + 1) begin
                            if (p >= 0 && p <= t_i - L_next) begin
                                mask_in_end[p] <= 14'd1;
                            end else begin
                                mask_in_end[p] <= 14'd0;
                            end
                        end
                        
                        // Copy to current masks
                        for (p = 0; p < MAX_MASK_BITS; p = p + 1) begin
                            mask_current_out[p] <= mask_out_end[p];
                            mask_current_in[p] <= mask_in_end[p];
                        end
                        
                        state <= PROCESS_INTERVAL;
                        current_interval <= 7'd0;
                    end
                end
                
                PROCESS_INTERVAL: begin
                    // Check if we've processed all intervals
                    if (current_interval >= n_intervals - 1) begin
                        state <= CHECK_LAST;
                    end else begin
                        // Compute gap and next L
                        gap <= interval_start[current_interval + 1] - interval_end[current_interval];
                        L_next <= interval_end[current_interval + 1] - interval_start[current_interval + 1];
                        
                        // Check if L_next > t_i
                        if (L_next > t_i) begin
                            state <= DONE_STATE;
                            result <= 1'b0;
                            status <= 2'd2;
                        end else begin
                            // Compute shift_limit
                            shift_limit <= (gap < t_i) ? gap : t_i;
                            
                            // Compute prefix sums for current masks
                            prefix_out[0] <= mask_current_out[0];
                            for (p = 1; p < MAX_MASK_BITS; p = p + 1) begin
                                prefix_out[p] <= prefix_out[p - 1] + mask_current_out[p];
                            end
                            
                            prefix_in[0] <= mask_current_in[0];
                            for (p = 1; p < MAX_MASK_BITS; p = p + 1) begin
                                prefix_in[p] <= prefix_in[p - 1] + mask_current_in[p];
                            end
                            
                            // Compute reachable start positions
                            for (q = 0; q < MAX_MASK_BITS; q = q + 1) begin
                                // Check if q is reachable from any p in mask_current_out
                                if (q >= shift_limit) begin
                                    if (prefix_out[q - shift_limit] > 0) begin
                                        // Can reach q from p = q - shift_limit (cost 0, same direction)
                                        mask_next_out_end[q] <= 14'd1;
                                    end else begin
                                        mask_next_out_end[q] <= 14'd0;
                                    end
                                end else begin
                                    mask_next_out_end[q] <= 14'd0;
                                end
                                
                                // Check if q is reachable from any p in mask_current_in
                                if (q + shift_limit < MAX_MASK_BITS) begin
                                    if (prefix_in[q + shift_limit] > 0) begin
                                        // Can reach q from p = q + shift_limit (cost 0, same direction)
                                        mask_next_in_end[q] <= 14'd1;
                                    end else begin
                                        mask_next_in_end[q] <= 14'd0;
                                    end
                                end else begin
                                    mask_next_in_end[q] <= 14'd0;
                                end
                            end
                            
                            // Intersect with valid start ranges for next interval
                            valid_out_start_low <= 0;
                            valid_out_start_high <= t_i - L_next;
                            valid_in_start_low <= L_next;
                            valid_in_start_high <= t_i;
                            
                            for (q = 0; q < MAX_MASK_BITS; q = q + 1) begin
                                if (q >= valid_out_start_low && q <= valid_out_start_high) begin
                                    mask_next_out_end[q] <= mask_next_out_end[q];
                                end else begin
                                    mask_next_out_end[q] <= 14'd0;
                                end
                                
                                if (q >= valid_in_start_low && q <= valid_in_start_high) begin
                                    mask_next_in_end[q] <= mask_next_in_end[q];
                                end else begin
                                    mask_next_in_end[q] <= 14'd0;
                                end
                            end
                            
                            // Update current masks
                            for (p = 0; p < MAX_MASK_BITS; p = p + 1) begin
                                mask_current_out[p] <= mask_next_out_end[p];
                                mask_current_in[p] <= mask_next_in_end[p];
                            end
                            
                            current_interval <= current_interval + 1;
                        end
                    end
                end
                
                CHECK_LAST: begin
                    // Check if the last interval is valid
                    L_next <= interval_end[current_interval] - interval_start[current_interval];
                    
                    if (L_next > t_i) begin
                        result <= 1'b0;
                        status <= 2'd2;
                    end else begin
                        result <= 1'b1;
                        status <= 2'd1;
                    end
                    
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule