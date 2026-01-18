#!/bin/bash

print_banner() {
    clear

    echo -e "${GREEN}┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${NC}  🔐  ${CYAN}SecureInit${NC} — Linux Security Bootstrap             ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}                                                              ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}  ${MAGENTA}Author:${NC} Eliot                                         ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}  ${MAGENTA}Version:${NC} ${VERSION}                                    ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}  ${MAGENTA}GitHub:${NC} https://github.com/AlekseyNice/SecureInit ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}                                                              ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}  ${YELLOW}Purpose:${NC}                                              ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}  Harden Linux servers with one safe command                  ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}                                                              ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}  ${CYAN}Features:${NC}                                             ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}   • SSH hardening                                           ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}   • UFW firewall                                            ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}   • Fail2ban protection                                     ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}   • Secure user & sudo                                      ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}   • Automatic security updates                              ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}                                                              ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}  ${RED}Run only on trusted servers${NC}                            ${GREEN}│${NC}"
    echo -e "${GREEN}└──────────────────────────────────────────────────────────────┘${NC}"

    echo
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}⚡ Secure. Predictable. Auditable.${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo
}
