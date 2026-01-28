module binomial_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] X,
    output reg [6:0] n,
    output reg [3:0] k,
    output reg done
);

    // Parameters
    localparam DATA_WIDTH = 16;
    localparam N_WIDTH = 7;
    localparam K_WIDTH = 4;
    localparam ADDR_WIDTH = 9;
    localparam NUM_ENTRIES = 300;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [8:0] addr;
    reg [6:0] n_reg;
    reg [3:0] k_reg;
    reg done_reg;

    // ROM arrays
    reg [6:0] rom_n [0:299];
    reg [3:0] rom_k [0:299];
    reg [15:0] rom_coeff [0:299];

    // ROM initialization
    integer i;
    initial begin
        // Precomputed ROM values (example entries)
        // n=0
        rom_n[0] = 7'd0; rom_k[0] = 4'd0; rom_coeff[0] = 16'd1;
        // n=1
        rom_n[1] = 7'd1; rom_k[1] = 4'd0; rom_coeff[1] = 16'd1;
        rom_n[2] = 7'd1; rom_k[2] = 4'd1; rom_coeff[2] = 16'd1;
        // n=2
        rom_n[3] = 7'd2; rom_k[3] = 4'd0; rom_coeff[3] = 16'd1;
        rom_n[4] = 7'd2; rom_k[4] = 4'd1; rom_coeff[4] = 16'd2;
        rom_n[5] = 7'd2; rom_k[5] = 4'd2; rom_coeff[5] = 16'd1;
        // n=3
        rom_n[6] = 7'd3; rom_k[6] = 4'd0; rom_coeff[6] = 16'd1;
        rom_n[7] = 7'd3; rom_k[7] = 4'd1; rom_coeff[7] = 16'd3;
        rom_n[8] = 7'd3; rom_k[8] = 4'd2; rom_coeff[8] = 16'd3;
        rom_n[9] = 7'd3; rom_k[9] = 4'd3; rom_coeff[9] = 16'd1;
        // n=4
        rom_n[10] = 7'd4; rom_k[10] = 4'd0; rom_coeff[10] = 16'd1;
        rom_n[11] = 7'd4; rom_k[11] = 4'd1; rom_coeff[11] = 16'd4;
        rom_n[12] = 7'd4; rom_k[12] = 4'd2; rom_coeff[12] = 16'd6;
        rom_n[13] = 7'd4; rom_k[13] = 4'd3; rom_coeff[13] = 16'd4;
        rom_n[14] = 7'd4; rom_k[14] = 4'd4; rom_coeff[14] = 16'd1;
        // ... (remaining entries would be filled similarly)
        
        // Initialize remaining entries to 0
        for (i = 15; i < 300; i = i + 1) begin
            rom_n[i] = 7'd0;
            rom_k[i] = 4'd0;
            rom_coeff[i] = 16'd0;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            addr <= 9'd0;
            done_reg <= 1'b0;
            n_reg <= 7'd0;
            k_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                        addr <= 9'd0;
                    end
                end
                
                SEARCH: begin
                    if (rom_coeff[addr] == X) begin
                        n_reg <= rom_n[addr];
                        k_reg <= rom_k[addr];
                        state <= DONE;
                    end else if (addr == 9'd299) begin
                        n_reg <= 7'd0;
                        k_reg <= 4'd0;
                        state <= DONE;
                    end else begin
                        addr <= addr + 9'd1;
                    end
                end
                
                DONE: begin
                    done_reg <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Output assignments
    always @(*) begin
        n = n_reg;
        k = k_reg;
        done = done_reg;
    end

endmodule