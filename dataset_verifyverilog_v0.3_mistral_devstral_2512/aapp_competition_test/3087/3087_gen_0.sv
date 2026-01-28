module dance_arrows #(
    parameter N = 8,
    parameter K_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [K_WIDTH-1:0] K,
    input wire [7:0] a [0:N-1],
    output reg [7:0] f [0:N-1],
    output reg valid,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] DECOMPOSE = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] CONSTRUCT = 3'd3;
    localparam [2:0] DONE      = 3'd4;
    localparam [2:0] ERROR     = 3'd5;

    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Cycle detection arrays
    reg [7:0] next [0:N-1];
    reg visited [0:N-1];
    reg [7:0] cycle_id [0:N-1];
    reg [7:0] pos_in_cycle [0:N-1];
    reg [7:0] cycle_start [0:N-1];
    reg [7:0] cycle_len [0:N-1];
    reg [7:0] num_cycles;

    // Check phase variables
    reg [7:0] current_L;
    reg [7:0] current_c_L;
    reg [7:0] d;
    reg [7:0] divisor;
    reg [7:0] gcd_temp;
    reg [7:0] d_found;

    // Construct phase variables
    reg [7:0] current_group;
    reg [7:0] current_offset;
    reg [7:0] current_idx;
    reg [7:0] current_element;
    reg [7:0] next_element;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            error <= 1'b0;
            cycle_count <= 10'd0;
            num_cycles <= 8'd0;
            current_L <= 8'd0;
            current_c_L <= 8'd0;
            d <= 8'd0;
            divisor <= 8'd0;
            gcd_temp <= 8'd0;
            d_found <= 8'd0;
            current_group <= 8'd0;
            current_offset <= 8'd0;
            current_idx <= 8'd0;
            current_element <= 8'd0;
            next_element <= 8'd0;
            for (i = 0; i < N; i = i + 1) begin
                f[i] <= 8'd0;
                visited[i] <= 1'b0;
                cycle_id[i] <= 8'd0;
                pos_in_cycle[i] <= 8'd0;
                cycle_start[i] <= 8'd0;
                cycle_len[i] <= 8'd0;
                next[i] <= a[i] - 8'd1;
            end
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= DECOMPOSE;
                    end
                end

                DECOMPOSE: begin
                    cycle_count <= cycle_count + 10'd1;
                    // Find cycles
                    reg [7:0] current;
                    reg [7:0] cycle_start_idx;
                    reg [7:0] cycle_length;
                    reg found_unvisited;
                    
                    found_unvisited = 1'b0;
                    for (i = 0; i < N; i = i + 1) begin
                        if (!visited[i]) begin
                            found_unvisited = 1'b1;
                            current = i;
                            cycle_start_idx = i;
                            cycle_length = 8'd0;
                            
                            while (!visited[current]) begin
                                visited[current] = 1'b1;
                                cycle_id[current] = num_cycles;
                                pos_in_cycle[current] = cycle_length;
                                cycle_length = cycle_length + 8'd1;
                                current = next[current];
                            end
                            
                            cycle_start[num_cycles] = cycle_start_idx;
                            cycle_len[num_cycles] = cycle_length;
                            num_cycles = num_cycles + 8'd1;
                        end
                    end
                    
                    if (!found_unvisited || cycle_count >= MAX_CYCLES) begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 10'd1;
                    // Check for valid divisors
                    reg [7:0] L;
                    reg [7:0] c_L;
                    reg [7:0] temp_K;
                    reg [7:0] temp_d;
                    reg [7:0] temp_gcd;
                    reg valid_d_found;
                    
                    valid_d_found = 1'b1;
                    
                    for (L = 1; L <= N; L = L + 1) begin
                        c_L = 8'd0;
                        for (i = 0; i < num_cycles; i = i + 1) begin
                            if (cycle_len[i] == L) begin
                                c_L = c_L + 8'd1;
                            end
                        end
                        
                        if (c_L > 8'd0) begin
                            temp_K = K;
                            temp_d = 8'd0;
                            valid_d_found = 1'b0;
                            
                            for (d = 1; d <= temp_K; d = d + 1) begin
                                if (temp_K % d == 8'd0) begin
                                    if ((L == 8'd1 && d > 8'd1) || (L != 8'd1)) begin
                                        // Compute gcd(L, K/d)
                                        temp_gcd = gcd(L, temp_K / d);
                                        if (temp_gcd == 8'd1) begin
                                            temp_d = d;
                                            valid_d_found = 1'b1;
                                            break;
                                        end
                                    end
                                end
                            end
                            
                            if (!valid_d_found) begin
                                state <= ERROR;
                                error <= 1'b1;
                            end
                        end
                    end
                    
                    if (valid_d_found && cycle_count >= MAX_CYCLES) begin
                        state <= CONSTRUCT;
                    end else if (valid_d_found) begin
                        state <= CONSTRUCT;
                    end
                end

                CONSTRUCT: begin
                    cycle_count <= cycle_count + 10'd1;
                    // Construct the output permutation
                    reg [7:0] group_size;
                    reg [7:0] group_idx;
                    reg [7:0] offset;
                    reg [7:0] idx;
                    reg [7:0] element;
                    reg [7:0] next_elem;
                    
                    for (L = 1; L <= N; L = L + 1) begin
                        c_L = 8'd0;
                        for (i = 0; i < num_cycles; i = i + 1) begin
                            if (cycle_len[i] == L) begin
                                c_L = c_L + 8'd1;
                            end
                        end
                        
                        if (c_L > 8'd0) begin
                            // Find divisor d
                            temp_K = K;
                            group_size = 8'd0;
                            for (d = 1; d <= temp_K; d = d + 1) begin
                                if (temp_K % d == 8'd0) begin
                                    if ((L == 8'd1 && d > 8'd1) || (L != 8'd1)) begin
                                        temp_gcd = gcd(L, temp_K / d);
                                        if (temp_gcd == 8'd1) begin
                                            group_size = d;
                                            break;
                                        end
                                    end
                                end
                            end
                            
                            // Group cycles and construct f
                            group_idx = 8'd0;
                            for (i = 0; i < num_cycles; i = i + 1) begin
                                if (cycle_len[i] == L) begin
                                    if (group_idx == group_size - 8'd1) begin
                                        // Process group
                                        for (offset = 0; offset < L; offset = offset + 1) begin
                                            for (idx = 0; idx < group_size; idx = idx + 1) begin
                                                element = cycle_start[i - idx] + offset;
                                                if (element >= N) begin
                                                    element = element - N;
                                                end
                                                next_elem = cycle_start[i - idx] + ((offset + 8'd1) % L);
                                                if (next_elem >= N) begin
                                                    next_elem = next_elem - N;
                                                end
                                                f[element] = next_elem + 8'd1;
                                            end
                                        end
                                        group_idx = 8'd0;
                                    else begin
                                        group_idx = group_idx + 8'd1;
                                    end
                                end
                            end
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    valid <= 1'b1;
                    state <= IDLE;
                end

                ERROR: begin
                    error <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // GCD function
    function [7:0] gcd(input [7:0] a, input [7:0] b);
        reg [7:0] x;
        reg [7:0] y;
        reg [7:0] temp;
        
        x = a;
        y = b;
        
        while (y != 8'd0) begin
            temp = y;
            y = x % y;
            x = temp;
        end
        
        gcd = x;
    endfunction

endmodule